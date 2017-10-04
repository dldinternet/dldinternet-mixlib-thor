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

      def capture_output
        @previous_stdout, $stdout = $stdout, StringIO.new
        begin
          yield
        rescue Exception => e
          previous_stdout.write $stdout.string
          raise e
        end

        $stdout.string
      ensure
        # Restore the previous value of stdout (typically equal to stdout).
        $stdout = @previous_stdout
      end

      def suppress_output
        @previous_stdout, $stdout = $stdout, StringIO.new
      end

      def restore_output
        string = $stdout.string
        $stdout = @previous_stdout
        string
      end

      def run
        # suppress_output
        capture_output do
          header(title: @title, align: 'center') if @title #&& !@title.empty?

          table border: true, encoding: :ascii do
            header_row
            idx = 0
            list = @object.is_a?(Array) ? @object : [@object]
            list.each do |obj|
              obj_row(idx, obj)
            end
          end
        end

        # string = restore_output
      rescue => exe
        restore_output
        raise exe
      end

      def header_row
        list = @object.is_a?(Array) ? @object : [@object]
        row color: 'light_yellow', bold: true, encoding: :ascii do
          list[0].each do |key, _|
            column key.to_s, width: widths[key] if (@columns.nil? || @columns.keys.include?(key))
          end
        end
      end

      def obj_row(idx, obj)
        row color: 'white', bold: false do
          if obj.is_a? Hash
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

      def format_it(item=nil)
        if item
          @object = item
          @is_a_hash = @object.is_a?(Hash)
          @widths = nil
        end
        run
      end
    end
  end
end
