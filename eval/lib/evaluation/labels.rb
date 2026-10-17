# frozen_string_literal: true

class Evaluation::Labels
  ROOT = File.join(Evaluation::ROOT, "results", "labels")

  BLIND = File.join(Evaluation::ROOT, "results", "blind")

  SECOND = File.join(Evaluation::ROOT, "results", "blind2")

  DEV = [ROOT, BLIND, SECOND].freeze

  DRAWN = File.join(Evaluation::ROOT, "results", "{holdout,human}", "*")

  VERDICTS = %w[tp fp].freeze

  def initialize(root, pending: false)
    @root = root
    @pending = pending
  end

  def verdict(key) = entries.dig(key, "label")

  def entries = @_entries ||= listed.reject { @pending && blank?(it) }.to_h { [it["key"], vetted(it)] }

  def listed = @_listed ||= Dir["#{@root}/*.yml"].flat_map { YAML.safe_load_file(it) || [] }

  private

  def blank?(entry) = entry["label"].to_s.strip.empty?

  def vetted(entry)
    return entry if VERDICTS.include?(entry["label"]) && !entry["why"].to_s.strip.empty?
    raise(ArgumentError, "label #{entry["key"]} needs a label (tp or fp) and a why")
  end
end
