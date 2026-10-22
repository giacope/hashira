# frozen_string_literal: true

class Hashira::CI::Comparison
  def initialize(current, recorded)
    @current = current
    @recorded = recorded
  end

  def diff
    moved = renamed
    grouped = Hashira::CI::Regroup.new(gone, @current)
    Hashira::CI::Diff.new(
      added: fresh - moved.keys - grouped.into, removed: gone - moved.values - grouped.from, worsened: worsened(moved)
    )
  end

  private

  def fresh = @current.keys - @recorded.keys

  def gone = @recorded.keys - @current.keys

  def renamed = fresh.to_h { [it, pool[@current[it].trace]&.shift] }.compact

  def pool = @_pool ||= gone.group_by { @recorded[it].trace }.except(nil)

  def worsened(moved)
    paired = (@current.keys & @recorded.keys).to_h { [it, it] }.merge(moved)
    paired.filter_map do |key, was|
      before = @recorded[was].magnitude
      after = @current[key].magnitude
      [key, before, after] if before.is_a?(Integer) && after.is_a?(Integer) && after > before
    end
  end
end
