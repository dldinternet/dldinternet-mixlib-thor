# frozen_string_literal: true

require 'dldinternet/formatters/colors'
require 'awesome_print'
require 'command_line_reporter'

module DLDInternet
  module Formatters
    # Table formatter
    # :reek:RepeatedConditional {enabled: false}
    class Table < DLDInternet::Formatters::Basic
      include CommandLineReporter

      attr_reader :widths
      attr_reader :is_a_hash

      def initialize(obj, format, title)
        super
        # self.formatter = ''
        @object = [@object] unless @object.is_a?(Array)
        @is_a_hash = @object[0].is_a?(Hash)
      end

      def run
        suppress_output

        header(title: @title, align: 'center') if @title

        table border: true, encoding: :ascii do
          header_row
          idx = 0
          @object.each do |obj|
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
              column key.to_s, width: widths[key]
            end
          end
        end
      end

      def obj_row(idx, obj)
        row color: 'white', bold: false do
          if @is_a_hash
            obj.each do |_, val|
              column val.to_s
            end
          else
            column obj.to_s, width: widths[idx]
            idx += 1
          end
        end
      end

      # :reek:DuplicateMethodCall {enabled: false}
      def widths
        unless @widths
          @widths = Hashie::Mash.new
          if @is_a_hash
            widths_hash
          else
            widths_array
          end
        end
        @widths
      end

      def widths_array
        idx = 0
        @object.each do |val|
          set_width(idx, val)
          idx += 1
        end
      end

      def widths_hash
        @object[0].each do |key, _|
          klen         = key.to_s.length
          wid          = @widths[key]
          @widths[key] = klen if !wid || wid < klen
        end
        @object.each do |obj|
          obj_width(obj)
        end
      end

      def set_width(idx, val)
        vlen         = val.to_s.length
        wid          = @widths[idx] || 0
        @widths[idx] = vlen if wid < vlen
      end

      def obj_width(obj)
        obj.each do |key, val|
          set_width(key, val)
        end
      end

      def format_it
        run
      end
    end
  end
end
