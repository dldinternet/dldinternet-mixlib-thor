module Dldinternet
  module Mixlib
    module Thor
      VERSION = '0.9.4'

      module Version # :nodoc: all
        MAJOR, MINOR, RELEASE, *OTHER = VERSION.split '.'

        NUMBERS = [MAJOR, MINOR, RELEASE, *OTHER].freeze
      end

      # Returns the version string for the library.
      def self.version
        VERSION
      end
    end
  end
end
