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

  def suites = @checks.map(&:entry).group_by(&:first).transform_values { |entries| tally(entries.map(&:last)) }

  def tally(rows) = { "passed" => rows.count { it["passed"] }, "total" => rows.size, "checks" => rows }
end
