require 'vcr'
require 'dldinternet/thor/vcr/logger'


module VCR
  class Configuration

    attr_accessor :logger

  end
end

module VCR
  # The media VCR uses to store HTTP interactions for later re-use.
  class Cassette

    attr_reader :options

  end
end
