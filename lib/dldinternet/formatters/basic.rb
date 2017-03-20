# frozen_string_literal: true

require 'json'
require 'yaml'

module DLDInternet
  module Formatters
    # Basic formatter
    class Basic
      attr_reader :format
      attr_reader :object
      attr_reader :title

      def initialize(obj, format, title)
        @object = obj
        @format = format
        @title  = title
      end

      def format_it
        case format.to_s.downcase
        when 'json'
          JSON.pretty_generate(object)
        when 'yaml'
          object.to_yaml
        when 'none'
          object
        else
          object.to_s
        end
      end
    end
  end
end
