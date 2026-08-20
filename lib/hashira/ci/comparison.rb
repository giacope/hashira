# frozen_string_literal: true

class Hashira::CI::Comparison
  def initialize(current, recorded)
    @current = current
    @recorded = recorded
  end

  def diff
    moved = renamed
    Hashira::CI::Diff.new(added: fresh - moved.keys, removed: gone - moved.values, worsened: worsened(moved))
  end

  private

  def fresh = @current.keys - @recorded.keys

  def gone = @recorded.keys - @current.keys

  def renamed = fresh.to_h { [it, pool[@current[it].trace]&.shift] }.compact

  def pool = @_pool ||= gone.group_by { @recorded[it].trace }.except(nil)

  def worsened(moved)
    paired(moved).filter_map { |key, was| entry(key, @recorded[was].magnitude, @current[key].magnitude) }
  end

  def paired(moved) = (@current.keys & @recorded.keys).to_h { [it, it] }.merge(moved)

  def entry(key, before, after)
    [key, before, after] if before.is_a?(Integer) && after.is_a?(Integer) && after > before
  end
end
