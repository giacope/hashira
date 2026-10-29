# frozen_string_literal: true

class Evaluation::Command
  SUITES = [
    Evaluation::Conformance, Evaluation::Graphs, Evaluation::Clones, Evaluation::Smells, Evaluation::Behaviour
  ].freeze

  HOME = Evaluation::Home.new

  RESULTS = HOME.join("results")

  CORPUS = HOME.join("tmp", "corpus")

  def initialize(argv, io: $stdout)
    @argv = argv
    @io = io
  end

  def status
    return shown(Evaluation::Page.new(compared)) if option("--compare")
    return shown(Evaluation::Page.new(agreed)) if option("--agree")
    shown(Evaluation::Record.new(board, RESULTS, corpus))
  end

  private

  def shown(page)
    page.print(@io)
    page.status
  end

  def board = Evaluation::Board.new(option("--label") || "run", tool, checks, corpus)

  def compared = report(option("--compare").split(",").map { JSON.parse(File.read(it)) })

  def report(boards) = Evaluation::Comparison.new(boards).markdown

  def agreed = Evaluation::Agreement.build(option("--agree"), option("--raters")&.split(",")).markdown

  def option(flag)
    index = @argv.index(flag)
    @argv[index + 1] if index
  end

  def tool = @_tool ||= Evaluation::Tool.build(option("--hashira") || raise(ArgumentError, "eval/run --hashira PATH"))

  def chosen = (option("--suites") || [*SUITES.map { it::SUITE }, "corpus"].join(",")).split(",")

  def checks = SUITES.select { chosen.include?(it::SUITE) }.flat_map { it.build(tool).checks } + corpus.checks

  def corpus
    return Evaluation::NoCorpus.new unless chosen.include?("corpus")
    @_corpus ||= Evaluation::Corpus.build(tool, option("--corpus") || CORPUS, draw, sizes)
  end

  def sizes = option("--samples").to_s.split(",").to_h { it.split("=") }.transform_values { Integer(it) }

  def draw = @_draw ||= Evaluation::Draw.build(option("--seed"))
end
