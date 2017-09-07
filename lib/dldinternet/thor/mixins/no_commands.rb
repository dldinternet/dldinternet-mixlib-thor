require 'thor'
require 'awesome_print'
require 'yaml'
require 'dldinternet/formatters'
require 'hashie/mash'
require 'dldinternet/thor/version'
require 'inifile'
require 'config/factory'

module DLDInternet
  module Thor
    LOG_LEVELS = [:trace, :debug, :info, :note, :warn, :error, :fatal, :todo]

    class OptionsMash < ::Hashie::Mash ; end

    module MixIns
      module NoCommands
        require 'dldinternet/mixlib/logging'
        include DLDInternet::Mixlib::Logging

        def validate_options
          OptionsMash.disable_warnings
          @options = OptionsMash.new(@options.to_h)
          if options[:log_level]
            log_level = options[:log_level].to_sym
            raise "Invalid log-level: #{log_level}" unless LOG_LEVELS.include?(log_level)
            options[:log_level] = log_level
          end
          @options[:log_level] ||= :warn
          @options[:format] ||= @options[:output]
          @options[:output] ||= @options[:format]
        end

        def load_inifile
          unless File.exist?(@options[:inifile])
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
          if File.exist?(@options[:config])
            begin
              envs = ::Config::Factory::Environments.load_file(@options[:config])
              if envs and envs.is_a?(Hash) and @options[:environment]
                @options[:environments] = ::Hashie::Mash.new(envs)
              else
                yaml = ::YAML.load(File.read(@options[:config]))
                if yaml
                  yaml.each {|key, value|
                    @options[key.to_s.gsub(%r{[-]}, '_').to_sym]=value
                  }
                else
                  msg = "#{options.config} is not a valid configuration!"
                  @logger.error msg
                  raise StandardError.new(msg)
                end
              end
            rescue ::Exception => e
              @logger.error "#{e.class.name} #{e.message}"
              raise e
            end
          else
            @logger.warn "#{options.config} not found"
          end
        end

        def parse_options
          validate_options

          lcs = ::Logging::ColorScheme.new( 'compiler', :levels => {
              :trace => :blue,
              :debug => :cyan,
              :info  => :green,
              :note  => :green,
              :warn  => :yellow,
              :error => :red,
              :fatal => :red,
              :todo  => :purple,
          })
          scheme = lcs.scheme
          scheme['trace'] = "\e[38;5;33m"
          scheme['fatal'] = "\e[38;5;89m"
          scheme['todo']  = "\e[38;5;55m"
          lcs.scheme scheme
          @config         = @options.dup
          @config[:log_opts] = lambda{|mlll| {
              :pattern      => "%#{mlll}l: %m %g\n",
              :date_pattern => '%Y-%m-%d %H:%M:%S',
              :color_scheme => 'compiler',
              :trace        => (@config[:trace].nil? ? false : @config[:trace]),
              # [2014-06-30 Christo] DO NOT do this ... it needs to be a FixNum!!!!
              # If you want to do ::Logging.init first then fine ... go ahead :)
              # :level        => @config[:log_level],
          }
          }
          @config[:log_levels] ||= LOG_LEVELS
          @options[:log_config] = @config
          # initLogging(@config)
          @logger = getLogger(@config)

          if @options[:inifile]
            @options[:inifile] = File.expand_path(@options[:inifile])
            load_inifile
          elsif @options[:config]
            @options[:config] = File.expand_path(@options[:config])
            if @options[:config] =~ /\.ini/i
              @options[:inifile] = @options[:config]
              load_inifile
            else
              load_config
            end
          end
          if options[:debug]
            @logger.info "Options:\n#{options.ai}"
          end

        end

        def abort!(msg)
          @logger.error msg
          exit -1
        end

        def notation
          @config[:output] || :none
        end

        def default_formatter(obj, opts=nil)
          opts ||= Hashie::Mash.new(options.to_h)
          format_helper = DLDInternet::Formatters::Basic.new(obj, notation, title: opts[:title], columns: opts[:columns])
          case notation.to_sym
          when :json
          when :yaml
          when :none
          when :basic
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
            hash = obj.is_a?(Array) ? obj.map { |o| hash_it(o) } : (obj.is_a?(String) ? obj : hash_it(obj))
            str = string_it(hash, fmtr, header)
            write str
          end
        end

        def command_pre(*args)
          parse_options
          @logger.info @_invocations.map{ |_,v| v[0]}.join(' ') if options[:verbose]
        end

        def command_out(res, fmtr=nil)
          unless fmtr
            fmtr = formatter.call(res, options)
            fmtr.table_widths
          end
          case options[:format]
          when /text|none|plain/
            output(header_line(res, fmtr), fmtr, true) unless options[:header] === false
            case res.class.name
            when /Array/
              res.each do |obj|
                output format_line(obj, fmtr)
              end
            # when /Hash|String/
            else
              output format_line(res, fmtr)
            end
          else
            output res
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
          super
        end

      end
    end
  end
end