# frozen_string_literal: true

class Evaluation::Comparison
  MEASURES = %w[files kloc seconds megabytes].freeze

  def initialize(boards)
    @boards = boards
  end

  def markdown = [suites, failures, corpus, precision].compact.join("\n")

  private

  def labels = @boards.map { it["label"] }

  def table(head, rows) = [line(head), "|#{head.map { " --- " }.join("|")}|", *rows.map { line(it) }].join("\n")

  def line(cells) = "| #{cells.join(" | ")} |"

  def suites
    names = @boards.flat_map { it["suites"].keys }.uniq
    "## Suites\n\n#{table(["suite", *labels], names.map { scores(it) })}\n"
  end

  def scores(name) = [name, *@boards.map { score(it.dig("suites", name)) }]

  def score(suite)
    return "—" unless suite
    "#{suite["passed"]}/#{suite["total"]} (#{(100.0 * suite["passed"] / suite["total"]).round(1)}%)"
  end

  def failures
    rows = @boards.last["suites"].flat_map { |name, suite| failed(name, suite) }
    rows.empty? ? nil : "## Failing checks (#{labels.last})\n\n#{table(%w[suite check expected actual], rows)}\n"
  end

  def failed(name, suite) = suite["checks"].reject { it["passed"] }.map { failure(name, it) }

  def failure(name, check) = [name, check["name"], *%w[expected actual].map { "`#{check[it].inspect}`" }]

  def corpus
    projects = @boards.flat_map { it.fetch("corpus", {}).keys }.uniq
    "## Corpus\n\n#{projects.map { project(it) }.join("\n")}" unless projects.empty?
  end

  def project(name)
    runs = @boards.map { it.dig("corpus", name) }
    kinds = runs.compact.flat_map { it["kinds"].keys }.uniq.sort
    rows = MEASURES.map { |key| [key, *runs.map { it&.fetch(key) }] } + kinds.map { kind(it, runs) }
    "### #{name}\n\n#{table(["", *labels], rows)}\n"
  end

  def kind(name, runs) = [name, *runs.map { |run| shown(run&.dig("kinds", name)) }]

  def shown(entry) = entry ? "#{entry["count"]} (#{entry["per_kloc"]}/kLOC)" : "0"

  def precision
    kinds = @boards.flat_map { it.fetch("precision", {}).keys }.uniq
    rows = kinds.map { |name| [name, *@boards.map { judged(it.dig("precision", name)) }] }
    "## Precision (labeled sample)\n\n#{table(["kind", *labels], rows)}\n" unless kinds.empty?
  end

  def judged(entry)
    return "—" unless entry && entry["labeled"].positive?
    "#{entry["tp"]}/#{entry["labeled"]} = #{entry["precision"]} #{bounds(entry)} of #{entry["population"]}"
  end

  def bounds(entry) = "[#{entry["low"]}, #{entry["high"]}]"
end
