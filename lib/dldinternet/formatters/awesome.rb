# frozen_string_literal: true

require 'awesome_print'

module DLDInternet
  module Formatters
    # Awesome formatter
    class Awesome
      attr_reader :format
      attr_reader :object
      attr_reader :title

      def initialize(obj, format, title)
        @object = obj
        @format = format
        @title  = title
      end

      def format_it
        object.ai
      end
    end
  end
end
