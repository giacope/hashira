# frozen_string_literal: true

class Evaluation::Board
  def initialize(label, tool, checks, corpus)
    @label = label
    @tool = tool
    @checks = checks
    @corpus = corpus
  end

  def to_h
    @_to_h ||= { "label" => @label, "commit" => @tool.commit, "ruby" => RUBY_VERSION }
      .merge("suites" => suites, **@corpus.measured)
  end

  def write(directory)
    File.write(File.join(directory, "#{@label}.json"), "#{JSON.pretty_generate(to_h)}\n")
    File.write(File.join(directory, "#{@label}.md"), markdown)
  end

  def markdown = Evaluation::Comparison.new([to_h]).markdown

  def passed? = to_h["suites"].values.all? { it["passed"] == it["total"] }

  private

  def suites = @checks.group_by(&:suite).transform_values { tally(it) }

  def tally(checks) = { "passed" => checks.count(&:passed?), "total" => checks.size, "checks" => checks.map(&:row) }
end
