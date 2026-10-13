# frozen_string_literal: true

class Evaluation::Labels
  ROOT = File.join(Evaluation::ROOT, "results", "labels")

  BLIND = File.join(Evaluation::ROOT, "results", "blind")

  DEV = [ROOT, BLIND].freeze

  VERDICTS = %w[tp fp].freeze

  def initialize(root)
    @root = root
  end

  def verdict(key) = entries.dig(key, "label")

  def entries
    @_entries ||= Dir["#{@root}/*.yml"].flat_map { YAML.safe_load_file(it) || [] }.to_h { [it["key"], vetted(it)] }
  end

  private

  def vetted(entry)
    return entry if VERDICTS.include?(entry["label"]) && !entry["why"].to_s.strip.empty?
    raise(ArgumentError, "label #{entry["key"]} needs a label (tp or fp) and a why")
  end
end
