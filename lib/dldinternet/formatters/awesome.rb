# frozen_string_literal: true

require 'awesome_print'
require 'dldinternet/formatters/basic'

module DLDInternet
  module Formatters
    # Awesome formatter
    class Awesome < DLDInternet::Formatters::Basic
      attr_reader :format
      attr_reader :object
      attr_reader :title

      def initialize(obj, format, options)
        super
      end

      def format_it
        object.ai
      end
    end
  end
end
