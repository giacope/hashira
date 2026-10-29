# frozen_string_literal: true

class Evaluation::Peak
  def self.of(path)
    seconds, kilobytes = File.exist?(path) ? File.read(path).split : [0, 0]
    new(Float(seconds), Integer(kilobytes))
  end

  def initialize(seconds, kilobytes)
    @seconds = seconds
    @kilobytes = kilobytes
  end

  def to_h = { "seconds" => @seconds.round(2), "megabytes" => (@kilobytes / 1024.0).round(1) }
end
