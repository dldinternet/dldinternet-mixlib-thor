require 'thor'
require 'awesome_print'
require 'yaml'
require 'dldinternet/formatters'
require 'hashie/mash'
require 'dldinternet/thor/version'
require 'dldinternet/thor/errors'
require 'inifile'
require 'config/factory'
require 'dldinternet/thor/vcr'
require 'active_support/core_ext/object/blank'

class String
  def to_bool
    return true   if self == true   || !self.match(/^(true|t|yes|y|1|on)$/i).nil?
    return false  if self == false  || self.blank? || !self.match(/^(false|f|no|n|0|off)$/i).nil?
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end
  alias :to_b :to_bool

  def class_from
    self.split('::').inject(Object) do |mod, class_name|
      mod.const_get(class_name)
    end
  end
  alias :to_class :class_from

end

class TrueClass
  def to_bool
    true
  end
  alias :to_b :to_bool
end

class FalseClass
  def to_bool
    false
  end
  alias :to_b :to_bool
end

module DLDInternet
  module Thor
    LOG_LEVELS = [:trace, :debug, :info, :note, :warn, :error, :fatal, :todo]

    class SilentMash < ::Hashie::Mash
      def initialize(source_hash = nil, default = nil, &blk)
        self.class.disable_warnings
        super
      end
    end
    class OptionsMash < SilentMash ; end
    class ConfigMash < SilentMash ; end

    module MixIns
      module NoCommands
        require 'dldinternet/mixlib/logging'
        include DLDInternet::Mixlib::Logging

        def validate_options(*args)
          writeable_options
          if options[:log_level]
            log_level = options[:log_level].to_sym
            raise "Invalid log-level: #{log_level}" unless LOG_LEVELS.include?(log_level)
            options[:log_level] = log_level
          end
          @options[:format] ||= @options[:output]
          @options[:output] ||= @options[:format]

          args.flatten!
          if !args.empty? && args.map{ |a| /^-/.match(a) }.any?
            raise DLDInternet::Thor::BadArgumentError, "Invalid arguments provided: #{args}"
          end
        end

        def writeable_options
          return if @options.is_a?(OptionsMash)
          @options = OptionsMash.new(@options.to_h)
        end

        def load_inifile
          unless !@options[:inifile].blank? && File.exist?(@options[:inifile])
            raise "#{@options[:inifile]} not found!"
          end
          begin
            ini = ::IniFile.load(@options[:inifile])
            ini['global'].each{ |key,value|
              @options[key.to_s]=value
              ENV[key.to_s]=value
            }
            def _expand(k,v,regex,rerun)
              matches = v.match(regex)
              if matches
                var = matches[1]
                if options[var]
                  options[k]=v.gsub(/\%\(#{var}\)/,options[var]).gsub(/\%#{var}/,options[var])
                else
                  rerun[var] = 1
                end
              end
            end

            pending = nil
            rerun = {}
            begin
              pending = rerun
              rerun = {}
              options.to_hash.each{|k,v|
                if v.to_s.match(/\%/)
                  _expand(k,v,%r'[^\\]\%\((\w+)\)', rerun)
                  _expand(k,v,%r'[^\\]\%(\w+)',     rerun)
                end
              }
              # Should break out the first time that we make no progress!
            end while pending != rerun
          rescue ::IniFile::Error => e
            # noop
          rescue ::Exception => e
            @logger.error "#{e.class.name} #{e.message}"
            raise e
          end
        end

        def load_config
          if @options[:configfile].blank?
            @logger.error 'Invalid/No configuration file specified'
          else
            @options[:configfile] = File.expand_path(@options[:configfile])
            if ::File.exist?(@options[:configfile])
              begin
                # envs = ::Config::Factory::Environments.load_file(@options[:configfile])
                hash = config_to_yaml
                envs = ::Config::Factory::Environments.load_hash(hash)
                if envs and envs.is_a?(Hash) and @options[:environment]
                  @options[:environments] = ::Hashie::Mash.new(envs)
                else
                  yaml = ::YAML.load(File.read(@options[:configfile]))
                  if yaml
                    yaml.each {|key, value|
                      @options[key.to_s.gsub(%r{[-]}, '_').to_sym]=value
                    }
                  else
                    msg = "#{options[:configfile]} is not a valid configuration!"
                    @logger.error msg
                    raise StandardError.new(msg)
                  end
                end
              rescue ::Exception => e
                @logger.error "#{e.class.name} #{e.message}"
                raise e
              end
            else
              @logger.warn "'#{options[:configfile]}' not found"
              @logger.error "Invalid/No configuration file specified"
              exit 2
              #@options[:environments] = ::Hashie::Mash.new
            end
          end
        end

        def solve_pointers(haystack, hash=nil)
          hash ||= haystack
          return haystack unless hash.is_a?(Hash) && hash.size

          hash.dup.each do |k,v|
            if %r{^[#/]}.match?(k) && v.nil?
              begin
                require 'hana'
                pointer = Hana::Pointer.new k
                v = pointer.eval(haystack)
                hash.delete(k)
                hash.merge!(v)
              rescue Exception => e
                require 'json-pointer'
                pointer = ::JsonPointer.new(haystack, k, :symbolize_keys => true)
                if pointer.exists?
                  hash.delete(k)
                  hash.merge!(pointer.value)
                end
              end
            end
          end
          hash.each do |k,v|
            if v && v.is_a?(Hash)
              haystack = solve_pointers(haystack, v)
            end
          end
          haystack
        end

        def config_to_yaml
          begin
            yaml = ConfigMash.new(::YAML.load(File.read(@options[:configfile])))
            yaml = solve_pointers(yaml)
            yaml
          rescue StandardError => e
            raise e
          end
        end

        def parse_options(*args)
          get_logger(true)

          args.flatten!
          check_for_help(args)
          validate_options(args)

          if @options[:inifile]
            @options[:inifile] = File.expand_path(@options[:inifile])
            load_inifile
          elsif @options[:configfile]
            @options[:configfile] = File.expand_path(@options[:configfile])
            if @options[:configfile] =~ /\.ini/i
              @options[:inifile] = @options[:configfile]
              load_inifile
            else
              load_config
            end
          end
          if options[:debug]
            @logger.info "Options:\n#{options.ai}"
          end

        end

        # Child classes can override this if desired
        def check_for_help(args)
          if args && args.size > 0 && (args[0] && args[0].downcase.eql?('help') || args.select {|a| a.match(/--help/i)}.any?)
            invocations = @_invocations.map {|_, v| v[0]}
            self.class.command_help(shell, invocations[-1], invocations)
            exit 0
          end
        end

        def get_logger(force=false)
          return unless force || @logger.nil?
          writeable_options
          @options[:log_level] ||= :warn
          lcs             = ::Logging::ColorScheme.new('compiler', :levels => {
              :trace => :blue,
              :debug => :cyan,
              :info  => :green,
              :note  => :green,
              :warn  => :yellow,
              :error => :red,
              :fatal => :red,
              :todo  => :purple,
          })
          scheme          = lcs.scheme
          scheme['trace'] = "\e[38;5;33m"
          scheme['fatal'] = "\e[38;5;89m"
          scheme['todo']  = "\e[38;5;55m"
          lcs.scheme scheme
          @config               = @options.dup
          @config[:log_opts]    = lambda {|mlll| {
              :pattern      => "%#{mlll}l: %m %g\n",
              :date_pattern => '%Y-%m-%d %H:%M:%S',
              :color_scheme => 'compiler',
              :trace        => (@config[:trace].nil? ? false : @config[:trace]),
              # [2014-06-30 Christo] DO NOT do this ... it needs to be a FixNum!!!!
              # If you want to do ::Logging.init first then fine ... go ahead :)
              # :level        => @config[:log_level],
          }
          }
          @config[:log_levels]  ||= LOG_LEVELS
          @options[:log_config] = @config
          # initLogging(@config)
          @logger = getLogger(@config)
        end

        def abort!(msg)
          @logger.error msg
          exit -1
        end

        def notation
          @config[:format] || :none
        end

        def default_formatter(obj, opts=nil)
          opts ||= Hashie::Mash.new(options.to_h)
          format_helper = DLDInternet::Formatters::Basic.new(obj, notation, title: opts[:title], columns: opts[:columns])
          case notation.to_sym
          when :json
          when :yaml
          when :csv
          when :none
          # when :basic
          when :text
            # noop
          when :awesome
            format_helper = DLDInternet::Formatters::Awesome.new(obj, notation, title: opts[:title], columns: opts[:columns])
          when :table
            format_helper = DLDInternet::Formatters::Table.new(obj, notation, title: opts[:title], columns: opts[:columns])
          else
            raise DLDInternet::Formatters::Error, "Unknown format requested: #{notation}"
          end
          format_helper
        end

        def default_header(obj, format_helper=nil)
          format_helper ||= default_formatter(obj)
          format_helper.header_it
        end

        def default_format(obj, opts=nil, format_helper=nil)
          format_helper ||= default_formatter(obj, opts || options)
          format_helper.format_it
        end

        def hash_it(robj)
          klass = robj.class
          repre = begin
            klass.const_get('Representation')
          rescue
            false
          end
          if robj.nil?
            robj
          elsif robj.respond_to?(:to_hash)
            robj.to_hash
          elsif robj.respond_to?(:to_a)
            robj.to_a.map { |obj| hash_it(obj) }
          elsif repre
            representation = repre.new(robj)
            representation.to_hash
          elsif robj.respond_to?(:to_h)
            robj.to_h
          else
            robj
          end
        end

        def string_it(obj, fmtr=nil, header=false)
          fmtr ||= @formatter.call(obj, options)
          fmtr.send(header ? :header_it : :format_it, obj)
        end

        def write(obj)
          writer.call(obj)
        end

        def output(obj, fmtr=nil, header=false)
          unless obj.nil?
            it = obj.is_a?(Array) ? obj.map { |o| hash_it(o) } : (obj.is_a?(String) ? obj : hash_it(obj))
            str = string_it(it, fmtr, header)
            write str
          end
        end

        def command_pre(*args)
          # args.flatten!
          parse_options(args)
          @logger.info @_invocations.map{ |_,v| v[0]}.join(' ') if options[:verbose]
          command_pre_start_vcr(args)
        end

        def command_post(rc=0)
          command_post_stop_vcr
          @command_post = true
          rc
        end

        def command_out(res, fmtr=nil)
          unless fmtr
            fmtr = formatter.call(res, options)
            fmtr.table_widths
          end
          # [2017-10-06 Christo] header_line and format_line serves to invoke client hooks if provided.
          # It means we may go through the process once with an object and a second time with a formatted string
          case options[:format]
          when /text|none|plain/
            output(header_line(res, fmtr), fmtr, true) unless options[:header] === false
            case res.class.name
            when /Array/
              fmtr.object.each do |obj|
                output format_line(obj, fmtr)
              end
            # when /Hash|String/
            else
              output format_line(fmtr.object || res, fmtr)
            end
          else
            output fmtr.object || res
          end
        end

        def header_line(obj, fmtr=nil)
          if obj.is_a?(String)
            obj
          elsif obj.is_a?(Hash)
            @header.call(obj, fmtr)
          elsif obj.is_a?(Array)
            if obj.size > 0
              header_line(obj[0], fmtr)
            else
              header_line({}, fmtr)
            end
          else
            raise "Cannot produce header from this object: #{obj.class.name}"
          end
        end

        def format_line(obj, fmtr=nil)
          @format.call(obj, fmtr)
        end

        def invoke_command(command, *args) #:nodoc:
          ::DLDInternet::Thor::Command.invocations = @_invocations.dup.map{ |_,v| v[0]}
          @command_options = command.options
          super
        end

        def handle_no_command_error(command, has_namespace = $thor_runner)
          get_logger unless @logger#:nodoc:
          @logger.error "Could not find command #{command.inspect} in #{namespace.inspect} namespace." if has_namespace
          @logger.error "Could not find command #{command.inspect}."
          1
        end

        protected

        def command_pre_start_vcr(*args)
          args.flatten!
          if options[:stubber].is_a?(String)
            options[:stubber] = options[:stubber].split(/\s*,\s*/).map(&:to_sym)
          elsif options[:stubber].is_a?(Array) && options[:stubber].size == 1 && options[:stubber][0].is_a?(String)
            options[:stubber] = options[:stubber][0].split(/\s*,\s*/).map(&:to_sym)
          elsif options[:stubber].is_a?(Array) && options[:stubber].size > 1 && options[:stubber][0].is_a?(String)
            options[:stubber] = options[:stubber].map(&:to_sym)
          end
          if options[:vcr]
            command_pre_vcr_cassette_path

            command_pre_config_vcr
            opts = args[0].is_a?(Hash) ? args.shift : {}
            unless options[:cassette]
              options[:cassette] = @_invocations.map{ |_,v| v[0]}.join('-')
              options[:cassette_not_given] = true
            end
            @cassette = ::VCR.insert_cassette(opts[:cassette] || options[:cassette])
          end
          yield if block_given?
        end

        def command_pre_vcr_cassette_path
          return if @command_pre_vcr_cassette_path

          cassette_path           = options[:cassette_path]
          unless cassette_path
            if ENV.has_key?('VCR_CASSETTE_PATH')
              cassette_path = ENV['VCR_CASSETTE_PATH']
            end
          end
          unless %r{^#{File::SEPARATOR}}.match?(cassette_path)
            if File.dirname($0).eql?(Dir.pwd)
              @logger.error "Saving fixtures to #{Dir.pwd}!"
              exit 1
            end
          end
          unless cassette_path
            cassette_path = vcr_default_cassette_path
          end
          options[:cassette_path] = File.expand_path(cassette_path)
          @command_pre_vcr_cassette_path = true
          cassette_path
        end

        def vcr_default_cassette_path
          '~/vcr_cassettes'
        end

        def command_pre_config_vcr
          @vcr_logger ||= ::DLDInternet::Thor::VCR::Logger.new(nil, @logger)
          ::VCR.configure do |config|
            config.cassette_library_dir = options[:cassette_path]
            config.hook_into *options[:stubber]
            config.logger = @vcr_logger
            config.default_cassette_options.merge!({ match_requests_on: [:method, :uri, :headers, :body], record: options[:record_mode] })
          end
        end

        def command_post_stop_vcr
          if options[:vcr]
            ::VCR.eject_cassette
            @cassette = nil
            @vcr_logger = nil
          end
        end
      end
    end
  end
end