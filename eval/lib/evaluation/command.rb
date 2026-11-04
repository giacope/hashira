# frozen_string_literal: true

class Evaluation::Command
  SUITES = [
    Evaluation::Conformance, Evaluation::Graphs, Evaluation::Clones, Evaluation::Smells, Evaluation::Behaviour
  ].freeze

  HOME = Evaluation::Home.new

  RESULTS = HOME.join("results")

  CORPUS = HOME.join("tmp", "corpus")

  USAGE = "eval/run --hashira PATH"

  def initialize(argv, io: $stdout)
    @argv = argv
    @io = io
  end

  def status
    return shown(Evaluation::Page.new(compared)) if option("--compare").any?
    return shown(Evaluation::Page.new(agreed)) if option("--agree").any?
    shown(Evaluation::Record.new(board, RESULTS, corpus))
  end

  private

  def shown(page)
    page.print(@io)
    page.status
  end

  def board = Evaluation::Board.new(option("--label").fetch(0, "run"), tool, checks, corpus)

  def compared = report(option("--compare").fetch(0).split(",").map { JSON.parse(File.read(it)) })

  def report(boards) = Evaluation::Comparison.new(boards).markdown

  def agreed = Evaluation::Agreement.build(option("--agree").fetch(0), *raters).markdown

  def raters = option("--raters").map { it.split(",") }

  def option(flag) = @argv.each_cons(2).select { |name, _value| name == flag }.first(1).map(&:last)

  def tool = @_tool ||= Evaluation::Tool.build(option("--hashira").fetch(0) { raise(ArgumentError, USAGE) })

  def chosen = option("--suites").fetch(0) { [*SUITES.map { it::SUITE }, "corpus"].join(",") }.split(",")

  def checks = SUITES.select { chosen.include?(it::SUITE) }.flat_map { it.build(tool).checks } + corpus.checks

  def corpus
    return Evaluation::NoCorpus.new unless chosen.include?("corpus")
    @_corpus ||= Evaluation::Corpus.build(tool, option("--corpus").fetch(0, CORPUS), draw, sizes)
  end

  def sizes = option("--samples").fetch(0, "").split(",").to_h { it.split("=") }.transform_values { Integer(it) }

  def draw = @_draw ||= Evaluation::Draw.build(option("--seed"))
end
