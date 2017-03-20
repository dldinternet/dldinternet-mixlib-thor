# frozen_string_literal: true

# require 'colorize'
require 'paint/shortcuts'
Paint.mode = 256
def RGB(*args)
  args
end
palette = {}
[:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white].each do |color|
  next if String.respond_to?(color)
  palette[color] = Paint.color(color)
  palette[:"light_#{color}"] = Paint.color(color, :bright)
end
palette[:copper]       = Paint.color RGB(225, 142, 121)
palette[:pancho]       = Paint.color RGB(229, 173, 148)
# "\\e[38;5;208m\\e[40m$*\\e[0m\\n"
palette[:pumpkin]      = Paint.color RGB(252, 120, 30)
palette[:tango]        = Paint.color RGB(240, 108, 23)
palette[:light_orange] = Paint.color RGB(248, 132, 127)
palette[:salmon]       = Paint.color RGB(234, 99, 44)
palette[:royal]        = Paint.color RGB(76, 114, 230)
palette[:cornflower]   = Paint.color RGB(104, 136, 234)
palette[:cf]           = Paint.color RGB(40, 114, 101)
palette[:genoa]        = Paint.color RGB(40, 114, 101)
palette[:trout]        = Paint.color RGB(77, 88, 89)
palette[:brick]        = Paint.color RGB(196, 48, 59)
palette[:matisse]      = Paint.color RGB(46, 94, 127)
palette[:tufts]        = Paint.color RGB(56, 137, 202)
Paint::SHORTCUTS[:thd] = palette
include Paint::Thd::String
