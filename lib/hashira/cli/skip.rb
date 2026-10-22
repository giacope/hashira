# frozen_string_literal: true

class Hashira::CLI::Skip
  def initialize(flag)
    @flag = flag
  end

  def parse(list)
    return [] unless list
    keys = list.split(",").map { key(it.strip) }
    raise(Hashira::Error, "cannot skip every analyzer") if (Hashira::Pipeline::ANALYZERS - keys).empty?
    keys
  end

  private

  def key(name)
    symbol = name.to_sym
    return symbol if Hashira::Pipeline::ANALYZERS.include?(symbol)
    raise(Hashira::Error, "unknown #{@flag} #{name.inspect} (use: #{Hashira::Pipeline::ANALYZERS.join(", ")})")
  end
end
