# frozen_string_literal: true

class Evaluation::Labels
  VERDICTS = %w[tp fp].freeze

  private_constant :VERDICTS

  def initialize(root, pending: false)
    @root = root
    @pending = pending
  end

  def verdicts(key) = entries.slice(key).values.map { it["label"] }

  def entries = @_entries ||= listed.reject { @pending && blank?(it) }.to_h { [it["key"], vetted(it)] }

  def listed = @_listed ||= Dir["#{@root}/*.yml"].flat_map { YAML.safe_load_file(it) || [] }

  private

  def blank?(entry) = entry["label"].to_s.strip.empty?

  def vetted(entry)
    return entry if VERDICTS.include?(entry["label"]) && !entry["why"].to_s.strip.empty?
    raise(ArgumentError, "label #{entry["key"]} needs a label (tp or fp) and a why")
  end
end
