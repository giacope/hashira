# frozen_string_literal: true

module Evaluation
  Accord =
    Data.define(:pairs) do
      def size = pairs.size

      def empty? = pairs.empty?

      def agreed = pairs.count { |human, rater| human == rater }

      def kappa
        chance = Labels::VERDICTS.sum { |verdict| share(0, verdict) * share(1, verdict) }
        chance == 1 ? "—" : ((agreed.fdiv(size) - chance) / (1 - chance)).round(2)
      end

      def share(side, verdict) = pairs.count { it[side] == verdict }.fdiv(size)

      def positive(side) = pairs.count { it[side] == "tp" }
    end
end

class Evaluation::Agreement
  RATERS = [Evaluation::Labels::BLIND, Evaluation::Labels::SECOND].freeze

  def self.build(human, raters)
    new(Evaluation::Labels.new(human, pending: true), (raters || RATERS).map { Evaluation::Labels.new(it) })
  end

  def initialize(human, raters)
    @human = human
    @raters = raters
  end

  def markdown = [precision, agreement || missing].join("\n")

  private

  def table(head, rows) = [line(head), "|#{head.map { " --- " }.join("|")}|", *rows.map { line(it) }].join("\n")

  def line(cells) = "| #{cells.join(" | ")} |"

  def kind(key) = key.split("|")[1]

  def kinds = [*@human.listed.map { kind(it["key"]) }.uniq.sort, nil]

  def judged(name) = @human.entries.select { |key, _entry| name.nil? || kind(key) == name }

  def listed(name) = @human.listed.count { name.nil? || kind(it["key"]) == name }

  def precision = "## Human precision\n\n#{table(["kind", "labelled", "tp (95% Wilson)"], kinds.map { scored(it) })}\n"

  def scored(name) = [name || "all", "#{judged(name).size}/#{listed(name)}", score(judged(name))]

  def score(entries)
    return "—" if entries.empty?
    tally = Evaluation::Tally.new(population: 0, sampled: 0, labeled: entries.size, positive: positives(entries)).to_h
    "#{tally["tp"]}/#{entries.size} = #{tally["precision"]} [#{tally["low"]}, #{tally["high"]}]"
  end

  def positives(entries) = entries.count { |_key, entry| entry["label"] == "tp" }

  def agreement
    rows = kinds.flat_map { |name| @raters.each_with_index.filter_map { |rater, index| row(name, rater, index) } }
    head = ["kind", "rater", "shared", "agree", "κ", "human tp", "rater tp"]
    "## Human and rater agreement\n\n#{table(head, rows)}\n" unless rows.empty?
  end

  def row(name, rater, index)
    accord = Evaluation::Accord.new(pairs: paired(name, rater))
    return if accord.empty?
    [name || "all", index + 1, accord.size, accord.agreed, accord.kappa, accord.positive(0), accord.positive(1)]
  end

  def paired(name, rater) = judged(name).filter_map { |key, entry| rater.verdict(key)&.then { [entry["label"], it] } }

  def missing = "No rater has labelled any of these keys yet, so this is human precision alone.\n"
end
