# frozen_string_literal: true

module Hashira::CLI::Skip
  module_function

  def parse(list)
    return [] unless list
    keys = list.split(",").map { key(it.strip) }
    raise(Hashira::Error, "cannot skip every analyzer") if (Hashira::Pipeline::ANALYZERS - keys).empty?
    keys
  end

  def key(name)
    symbol = name.to_sym
    Hashira::Pipeline::ANALYZERS.include?(symbol) ? symbol : unknown(name)
  end

  def unknown(name)
    raise(Hashira::Error, "unknown --skip #{name.inspect} (use: #{Hashira::Pipeline::ANALYZERS.join(", ")})")
  end
end
