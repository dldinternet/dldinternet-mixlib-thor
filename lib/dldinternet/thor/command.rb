require 'thor'
require 'awesome_print'

module DLDInternet
  module Thor
    class Command < ::Thor
      no_commands do

        require 'dldinternet/thor/mixins/no_commands'
        include DLDInternet::Thor::MixIns::NoCommands

      end

      class << self
        attr_accessor :invocations

        def namespace
          parts = self.name.split(/::/)
          parts[parts.size > 2 ? -2 : -1].downcase
        end

        # def command(scommand, usage, description, options = {}, &block)
        #   desc usage, description, options
        #   define_method(scommand) do |*args|
        #     args, opts = ::Thor::Arguments.split(args)
        #     block.call(args)
        #   end
        # end
        # alias_method :task, :command

        def command_help(shell, command_name, invocations=[])
          super(shell, command_name)
          0
        end

        def handle_argument_error(command, error, args, arity) #:nodoc:
          command_s = banner(command)
          # msg = "ERROR: \"#{basename} #{command.name}\" was called with "
          msg = "ERROR: \"#{command_s}\" was called with "
          msg << "no arguments"               if     args.empty?
          msg << "arguments " << args.inspect unless args.empty?
          msg << "\nUsage: #{command_s}"
          raise ::Thor::InvocationError, msg
        end

        protected

        def banner(command, namespace = nil, subcommand = false)
          "#{basename} #{::DLDInternet::Thor::Command.invocations ? "#{::DLDInternet::Thor::Command.invocations.join(' ') } " : ''}#{command.formatted_usage(self, $thor_runner, subcommand)}"
        end

      end

      attr_accessor :formatter, :writer, :header, :format

      def initialize(args = [], local_options = {}, config = {})
        super(args,local_options,config)
        @log_level = :warn #|| @config[:log_level].to_sym
        @formatter ||= ->(hsh, tit) { default_formatter(hsh, tit) }
        @writer    ||= ->(str) { puts str }
        @header ||= ->{}
        @format ||= ->(res) { puts res.ai }
      end

      desc "help [COMMAND]", "Describe available commands or one specific command"
      def help(command = nil, subcommand = false)
        ::DLDInternet::Thor::Command.invocations = @_invocations.dup.map{ |_,v| v[0]}
        # self.class.invocations[-1] = command
        ::DLDInternet::Thor::Command.invocations.pop if ::DLDInternet::Thor::Command.invocations[-1].eql?('help')
        ::DLDInternet::Thor::Command.invocations.pop if ::DLDInternet::Thor::Command.invocations[-1].eql?(command) || (!command && subcommand)
        super(command, subcommand)
        # if command
        #   if self.class.subcommands.include? command
        #     self.class.subcommand_classes[command].help(shell, true)
        #   else
        #     self.class.command_help(shell, command, invocations)
        #   end
        # else
        #   self.class.help(shell, subcommand)
        # end
        0
      end

    end
  end
end