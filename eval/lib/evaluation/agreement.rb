# frozen_string_literal: true

class Evaluation::Agreement
  RATERS = Evaluation::Shelves.new.raters

  def self.build(human, raters = RATERS)
    new(Evaluation::Labels.new(human, pending: true), raters.map { Evaluation::Labels.new(it) })
  end

  def initialize(human, raters)
    @human = human
    @raters = raters
  end

  def markdown = [precision, agreement].join("\n")

  private

  def table(head, rows) = [line(head), "|#{head.map { " --- " }.join("|")}|", *rows.map { line(it) }].join("\n")

  def line(cells) = "| #{cells.join(" | ")} |"

  def kind(key) = key.split("|").fetch(1)

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
    rows.empty? ? missing : "## Human and rater agreement\n\n#{table(head, rows)}\n"
  end

  def row(name, rater, index)
    accord = Evaluation::Accord.new(paired(name, rater))
    return if accord.empty?
    [name || "all", index + 1, *accord.cells]
  end

  def paired(name, rater) = judged(name).flat_map { |key, entry| rater.verdicts(key).map { [entry["label"], it] } }

  def missing = "No rater has labelled any of these keys yet, so this is human precision alone.\n"
end
