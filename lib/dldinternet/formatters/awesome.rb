# frozen_string_literal: true

require 'awesome_print'
require 'dldinternet/formatters/basic'

module DLDInternet
  module Formatters
    # Awesome formatter
    class Awesome < DLDInternet::Formatters::Basic

      def initialize(obj, format, options)
        super
      end

      def format_it(item=nil)
        item ||= object
        item.ai
      end
    end
  end
end
