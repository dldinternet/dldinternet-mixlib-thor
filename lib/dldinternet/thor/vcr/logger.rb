require 'vcr/util/logger'

module DLDInternet
  module Thor
    module VCR
      class Logger < ::VCR::Logger
        attr_reader :options

        def initialize(stream, logger=nil, options = {})
          super(stream)
          @logger = logger
          @options = options
        end

        def log(message, log_prefix, indentation_level = 0)
          indentation = '  ' * indentation_level
          log_message = indentation + log_prefix + message
          @logger.debug(log_message)
        end

      end
    end
  end
end