# frozen_string_literal: true

class Hashira::CLI::Skip
  def initialize(flag, checks = Hashira::Checks.new)
    @flag = flag
    @checks = checks
  end

  def parse(list)
    return [] unless list
    keys = list.split(",").map { key(it.strip) }
    raise(Hashira::Error, "cannot skip every analyzer") if (analyzers - keys).empty?
    keys
  end

  private

  def key(name)
    symbol = name.to_sym
    return symbol if analyzers.include?(symbol)
    raise(Hashira::Error, "unknown #{@flag} #{name.inspect} (use: #{analyzers.join(", ")})")
  end

  def analyzers = @checks.analyzers
end
