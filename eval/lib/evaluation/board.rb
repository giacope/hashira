# frozen_string_literal: true

class Evaluation::Board
  def initialize(label, tool, checks, corpus)
    @label = label
    @tool = tool
    @checks = checks
    @corpus = corpus
  end

  def to_h
    { "label" => @label, "commit" => @tool.commit, "ruby" => RUBY_VERSION }.merge("suites" => suites, **measured)
  end

  def write(directory)
    payload = to_h
    File.write(File.join(directory, "#{@label}.json"), "#{JSON.pretty_generate(payload)}\n")
    File.write(File.join(directory, "#{@label}.md"), Evaluation::Comparison.new([payload]).markdown)
    payload
  end

  private

  def measured = @corpus ? { "corpus" => @corpus.metrics, "precision" => @corpus.precision.summary } : {}

  def suites = @checks.group_by(&:suite).transform_values { tally(it) }

  def tally(checks) = { "passed" => checks.count(&:passed?), "total" => checks.size, "checks" => checks.map(&:row) }
end
