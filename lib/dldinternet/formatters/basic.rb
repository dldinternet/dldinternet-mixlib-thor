# frozen_string_literal: true

require 'json'
require 'yaml'
require 'csv'
require 'awesome_print'
require 'hashie/mash'

module DLDInternet
  module Formatters
    # Basic formatter
    class Basic
      attr_reader :format
      attr_reader :object
      attr_reader :title
      attr_reader :columns
      attr_reader :is_a_hash
      attr_reader :widths
      attr_reader :options

      def initialize(obj, format, options)
        @options = options
        @object = obj
        @format = format
        @title  = options[:title] || nil
        @is_a_hash = @object.is_a?(Hash)
        @columns = options[:columns] || nil
        if @columns
          @columns = Hashie::Mash.new(Hash[@columns.split(/\s*,\s*/).map{ |c| [c, nil]}])
          @columns.dup.map{ |h,v|
            submap!(h, v)
          }
          @object = columnize_item(@object)
        end
        # unless @columns.nil?
        #   @object = columnize_item(@object)
        # end
      end

      def header_it(item=nil)
        item ||=
            if @is_a_hash
              if @columns.nil?
                object.keys
              else
                @columns.keys
              end
            else
              object.to_s
            end
        item = if item.is_a?(Hash)
          if @columns.nil?
            item.keys
          else
            @columns.keys
          end
        else
          item
        end

        format_item item, true
      end

      def format_it(item=nil)
        item ||=
            if @is_a_hash
              if @columns.nil?
                object
              else
                hsh = {}
                object.each do |key,val|
                  hsh[key] = val  if @columns.keys.include?(key)
                end
                hsh
              end
            else
              object
            end

        format_item item
      end

      # :reek:DuplicateMethodCall {enabled: false}
      def widths
        unless @widths
          @widths = Hashie::Mash.new
          if @is_a_hash
            widths_hash
          elsif @object.is_a?(Array)
            widths_array
          else
            widths_object
          end
        end
        @widths
      end

      # :reek:DuplicateMethodCall {enabled: false}
      def widths=(w)
        @widths = w
      end

      # :reek:DuplicateMethodCall {enabled: false}
      def table_widths
        if object.is_a?(Array) && object.size > 0 && object[0].is_a?(Hash)
          tws = nil
          object.each do |obj|
            fmt = self.class.new(obj, format, options)
            tws ||= fmt.widths
            fmt.widths.each { |c,w|
              if tws[c] < w
                tws[c] = w
              end
            }
          end
          @widths = tws
        else
          widths
        end
      end

      private

      def format_item(item, header=false)
        fmt = format.to_s.downcase
        # if /json|yaml|csv/.match?(fmt)
        #   item = if @columns.nil?
                 #   item
                 # else
        item = object_item(item, header)
        case fmt
        when 'json'
          JSON.pretty_generate(item)
        when 'yaml'
          item.to_yaml
        when 'csv'
          columns = if @columns.nil?
                      if item.is_a?(Array)
                        if item[0].is_a?(Array)
                          # [2017-10-06 Christo] Assume first row is headings?
                          item[0] # raise StandardError, "Cannot find column headings"
                        elsif item[0].is_a?(Hash)
                          item[0].keys
                        else
                          # [2017-10-06 Christo] Assume first row is headings?
                          item
                        end
                      elsif item.is_a?(Hash)
                        item.keys
                      else
                        item
                      end
                    else
                      @columns.keys.map{ |k| subkeys(k) }
                    end
          nitm = if item.is_a?(Array)
                  item.map { |itm|
                    if itm.is_a?(Array)
                      itm
                    elsif itm.is_a?(Hash)
                      itm.values.map{|v| v.nil? ? '' : v}
                    else
                      [itm]
                    end
                  }
                elsif item.is_a?(Hash)
                  itm.values.map{|v| v.nil? ? '' : v}
                else
                  [itm]
                 end
          nitm.unshift(columns)
          header_row = true
          nitm.map! { |row|
            o = CSV::Row.new(columns,row,header_row)
            header_row = false
            o
          }
          csv = CSV::Table.new(nitm).to_csv
        when 'none'
          # columnize_item(item).to_s
          item
        else
          if item.is_a?(Array) # header ||
            if widths.is_a?(Hash)
              if @columns.nil?
                wdths = widths.map { |c,w| w }
              else
                wdths = widths.map { |c,w| w if @columns.include?(c) }.select{ |w| !w.nil? }
              end
            end
            i = -1
            nitm = item.map{ |c|
              i += 1
              w  = wdths[i]
              sprintf("%-#{w}s", c.to_s)
            }
            nitm.join(" ")
          elsif item.is_a?(Hash)
            nitm = item.map do |key, val|
              if @columns.nil? || @columns.keys.include?(key) #&& @columns[key].nil?)
                sprintf("%-#{widths[key]}s", subcolumn(key, val))
                # sprintf("%-#{widths[key]}s", val.to_s)
              # elsif !key.index('.').nil?
              #   sprintf("%-#{widths[key]}s", subcolumn(key, val))
              end
            end
            nitm = nitm.select{|s| !s.nil?}.join(" ")
            nitm
          else
            item.to_s
          end
        end
      end

      def object_item(item, header=false)
        unless @columns.nil? || header
          item = if item.is_a?(Array)
                   nitm = item.map do |itm|
                     map_item(itm)
                   end
                   nitm
                 elsif item.is_a?(Hash)
                   map_item(item)
                 else
                   item
                 end
          # end
        end
        item
      end

      def map_item(item)
        itm  = columnize_item(item)
        mitm = itm.map do |key, val|
          k, v = [subkeys(key), subcolumn(key, val)]
          v.nil? ? nil : [k, v]
          # if @columns.keys.include?(key)
          # if @columns[key].nil?
          #   [key,val]
          # else
          #   raise "What now"
          # end
          # end
        end
        mitm = mitm.select {|e| !e.nil?} #&& !e[1].nil? }
        Hash[mitm]
      end

      def columnize_item(item)
        return item if @columns.nil?
        if item.is_a?(Array)
          itm = item.map { |obj|
            columnize_item(obj)
          }
        else
          itm = {} # ::Hashie::Mash.new
          @columns.map {|k, _|
            itm[k] = item[k]
          }
        end
        itm
      end

      def submap!(col, val, sub=nil)
        sub ||= @columns
        m = col.match(/^([^.]+)\.(.*)$/)
        if m
          val = sub[m[1]]
          val ||= {} # Hashie::Mash.new
          submap!(m[2], val, val)
          sub[m[1]] = val
          sub.delete(col)
        else
          if val
            val[col] = nil
          else
            sub[col] = val
          end
        end
      end

      def widths_object
        set_width(0, @object)
      end

      def widths_array
        @object.each do |val|
          widths_hash(val)
        end
      end

      def widths_hash(item=nil)
        item ||= @object
        item.each do |key, _|
          klen         = (@columns.nil? ? key : subkeys(key, @columns)).to_s.length
          wid          = @widths[key]
          @widths[key] = klen if !wid || wid < klen
        end
        obj_width(item)
      end

      def set_width(idx, val)
        vlen         = val.to_s.length
        wid          = @widths[idx] || 0
        @widths[idx] = vlen if wid < vlen
      end

      def obj_width(obj)
        obj.each do |key, val|
          set_width(key, @columns.nil? ? val : subvalues(key, val, obj))
        end
      end

      def column(text, options = {})
        text
      end

      def subcolumn(key, val, sub=nil)
        if @columns.nil?
          column(val.to_s)
        else
          sub ||= @columns
          if sub[key]
            if sub[key].is_a?(Hash)
              vals = subvalues(key, val, sub)
              if vals.is_a?(Array)
                vals.flatten!
                # vals = vals[0] if vals.size == 1
              end
              column(vals.to_s)
            else
              column(val.to_s) if sub.has_key?(key)# && sub[key].nil?
            end
          else
            column(val.to_s)  if sub.has_key?(key) # && sub[key].nil?)
          end
        end
      end

      def subvalues(key, val, sub)
        sk = sub[key]
        if sk.is_a?(Hash)
          sk.keys.map {|k|
            case val.class.name
            when /Hash$/
              val[k]
            when /Array$/
              val.map {|v|
                subvalues(k, v[k], sub[key])
              }
            else
              raise "Not catering for #{val.class.name}"
            end
          }
        elsif sk.is_a?(Array)
          fsk = sk.map {|v|
            h = @columns.nil? ? v : @columns[key]
            fv = h ? h.keys.map { |k|
              subvalues(k, v[k], v)
            } : v
            fv = simple_value(fv)
            fv
          }.flatten
          fsk
        else
          val
        end
      end

      def simple_value(fv)
        if fv.is_a?(Hash)
          fv.to_hash
        elsif fv.is_a?(Array)
          fv.map{ |v| simple_value(v) }
        elsif fv.is_a?(String)
          fv
        else
          raise "Not catering for #{fv.class.name}"
        end
      end

      def subkeys(key, sub=nil)
        sub ||= @columns
        if sub && sub[key]
          if sub[key].is_a?(Hash)
            keys = sub[key].map { |k,v|
              key+'.'+subkeys(k, v ? v : {})
            }
            if keys.is_a?(Array)
              keys = keys.flatten
            end
            keys.join('.')
          else
            [key,subkeys(key, sub[key])].flatten if sub.has_key?(key)
          end
        else
          key.to_s
        end
      end

    end
  end
end
