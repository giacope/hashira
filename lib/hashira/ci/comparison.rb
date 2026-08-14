# frozen_string_literal: true

class Hashira::CI::Comparison
  def initialize(current, recorded)
    @current = current
    @recorded = recorded
  end

  def diff
    current = @current.keys
    recorded = @recorded.keys
    Hashira::CI::Diff.new(added: current - recorded, removed: recorded - current, worsened:)
  end

  private

  def worsened
    (@current.keys & @recorded.keys).filter_map { entry(it, @recorded[it], @current[it]) }
  end

  def entry(key, before, after)
    [key, before, after] if before.is_a?(Integer) && after.is_a?(Integer) && after > before
  end
end
