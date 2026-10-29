# frozen_string_literal: true

class Hashira::CI::Scope
  FLAGS = { analyzers: "the analyzers", targets: "the directories" }.freeze

  WIDENED = "baseline %s was recorded with %s %s, but this run uses %s — rerun the recorded way, " \
    "or refresh it with --update-baseline"

  def initialize(analyzers:, targets:)
    @analyzers = analyzers
    @targets = targets
  end

  def to_h = { analyzers: @analyzers.map(&:to_s).sort, targets: @targets.sort }

  def widened(recorded, baseline)
    to_h.filter_map do |key, now|
      was = recorded.fetch(key.to_s, now)
      format(WIDENED, baseline, FLAGS.fetch(key), was.join(", "), now.join(", ")) unless was.sort == now.sort
    end
  end
end
