# frozen_string_literal: true

class Hashira::CI::Marks
  def initialize(magnitudes = {}, traces = {})
    @magnitudes = magnitudes
    @traces = traces
  end

  def call(signature, magnitude, traces)
    known = @magnitudes.key?(signature)
    sizes = @magnitudes.merge(signature => [@magnitudes[signature], magnitude].compact.max)
    Hashira::CI::Marks.new(sizes, known ? @traces : @traces.merge(traces.to_h { [signature, it] }))
  end

  def to_h = { findings: @magnitudes.sort.to_h }.merge(@traces.empty? ? {} : { traces: @traces.sort.to_h })

  def size = @magnitudes.size

  def against(recorded)
    gone = recorded.keys - keys
    moved = recorded.moved(@traces.slice(*fresh(recorded)), gone)
    Hashira::CI::Diff.new(*changed(recorded, moved, gone), worsened(recorded, moved))
  end

  def within(current)
    seen = @magnitudes.select { |key, _size| current.seen?(key, @traces[key]) }
    Hashira::CI::Marks.new(seen, @traces.slice(*seen.keys))
  end

  protected

  def keys = @magnitudes.keys

  def seen?(key, trace) = @magnitudes.key?(key) || (!trace.nil? && @traces.value?(trace))

  def moved(traced, gone)
    pool = gone.group_by { @traces[it] }.except(nil)
    traced.to_h { |key, trace| [key, pool[trace]&.shift] }.compact
  end

  def size_of(key) = @magnitudes.fetch(key)

  private

  def fresh(recorded) = keys.sort - recorded.keys

  def changed(recorded, moved, gone)
    grouped = Hashira::CI::Regroup.new(gone, @magnitudes)
    [fresh(recorded) - moved.keys - grouped.into, gone - moved.values - grouped.from]
  end

  def worsened(recorded, moved)
    paired = (keys.sort & recorded.keys).to_h { [it, it] }.merge(moved)
    paired.filter_map do |key, was|
      before = recorded.size_of(was)
      after = @magnitudes.fetch(key)
      [key, before, after] if before.is_a?(Integer) && after.is_a?(Integer) && after > before
    end
  end
end
