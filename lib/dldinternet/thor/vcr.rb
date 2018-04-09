require 'vcr'
require 'dldinternet/thor/vcr/logger'

require 'vcr/cassette/http_interaction_list'
require 'vcr/cassette/erb_renderer'
require 'vcr/cassette/serializers'


module VCR
  class Configuration

    attr_accessor :logger

  end

  # The media VCR uses to store HTTP interactions for later re-use.
  class Cassette
    class << self
      attr_accessor :logger
    end
    attr_reader :options

    def raw_cassette_bytes
      unless @raw_cassette_bytes
        path = @persister.absolute_path_to_file(storage_key)
        if File.exist?(path)
          # Log as info ONE time
          VCR::Cassette.logger ? VCR::Cassette.logger.info( "Loading cassette '#{@name}' ...") : log( "Loading cassette ...")
        else
          # Log as debug on every request
          VCR::Cassette.logger ? VCR::Cassette.logger.debug( "Cassette '#{@name}' not found!") : log( "Cassette not found ...")
        end
      end
      @raw_cassette_bytes ||= VCR::Cassette::ERBRenderer.new(@persister[storage_key], erb, name).render
    end
  end
end
