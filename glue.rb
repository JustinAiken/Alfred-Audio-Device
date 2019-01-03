#!/usr/bin/env ruby

require "yaml"
DATA = YAML.load_file("config.yml") rescue {}

class DeviceList
  attr_accessor :direction, :devices

  HEADER = %Q{<?xml version="1.0"?>\n<items>\n}
  FOOTER = "</items>\n"

  def initialize(direction)
    @direction = direction
  end

  def list!
    read!
    mark_current!
    output!
  end

  def read!
    @devices = `./SwitchAudioSource -at #{direction}`
      .split("\n")
      .map    { |device| Device.from(device) }
      .select { |device| device.displayable? }
  end

  def mark_current!
    current = `./SwitchAudioSource -ct #{direction}`
      .gsub("(input)", "")
      .gsub("(output)", "")
      .strip

    devices
      .select { |device| device.name == current }
      .each   { |device| device.set_current! }
  end

  def output!
    puts HEADER
    devices.each { |device| puts device.to_item }
    puts FOOTER
  end
end

class Device

  attr_accessor :name, :direction, :icon, :is_current

  def self.from(switch_audio)
    name = switch_audio
      .gsub("(input)", "")
      .gsub("(output)", "")
      .strip

    direction = switch_audio =~ /input/i ? :input : :output

    icon = DATA.fetch(name, {})["icon"] || "icon.png"

    self.new(name, direction, icon)
  end

  def initialize(name, direction, icon)
    @name, @direction, @icon = name, direction, icon
  end

  def set_current!
    @is_current = true
  end

  def display_name
    front = is_current ? "*** " : ""
    back  = (DATA[name] || {})["display"] || name
    "#{front}#{back}"
  end

  def displayable?
    return false if DATA.dig(name, "hide").to_s == direction.to_s
    return false if DATA.dig(name, "hide").to_s == "all"
    true
  end

  def uid
    name.gsub " ", "-"
  end

  def to_item
    %Q{<item arg="#{name}" uid="#{uid}"><title>#{display_name}</title><subtitle/><icon>#{icon}</icon></item>}
  end
end

action    = ARGV[0]
direction = ARGV[1]
requested = ARGV[2]

case action.to_s
when "list" then DeviceList.new(direction).list!
when "set"  then puts `./SwitchAudioSource -t #{direction} -s "#{requested}"`
end
