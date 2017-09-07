# frozen_string_literal: true

require 'dldinternet/formatters/basic'
require 'dldinternet/formatters/colors'
require 'command_line_reporter'

module DLDInternet
  module Formatters
    # Table formatter
    # :reek:RepeatedConditional {enabled: false}
    class Table < DLDInternet::Formatters::Basic
      include CommandLineReporter

      def initialize(obj, format, options)
        super
        # @object = [@object] unless @object.is_a?(Array)
        @values  = Hashie::Mash.new
      end

      def run
        suppress_output

        header(title: @title, align: 'center') if @title #&& !@title.empty?

        table border: true, encoding: :ascii do
          header_row
          idx = 0
          list = @object.is_a?(Array) ? @object : [@object]
          list.each do |obj|
            obj_row(idx, obj)
          end
        end

        capture_output
      rescue => exe
        restore_output
        raise exe
      end

      def header_row
        if @is_a_hash
          row color: 'light_yellow', bold: true, encoding: :ascii do
            @object[0].each do |key, _|
              column key.to_s, width: widths[key] if (@columns.nil? || @columns.keys.include?(key))
            end
          end
        end
      end

      def obj_row(idx, obj)
        row color: 'white', bold: false do
          if @is_a_hash
            obj.each do |key, val|
              if @columns.nil? || (@columns.keys.include?(key) && @columns[key].nil?)
                column val.to_s
              else
                subcolumn(key, val)
              end
            end
          else
            column obj.to_s, width: widths[idx]
            idx += 1
          end
        end
      end

      def format_it
        run
      end
    end
  end
end
