# frozen_string_literal: true

class Evaluation::Command
  SUITES = [
    Evaluation::Conformance, Evaluation::Graphs, Evaluation::Clones, Evaluation::Smells, Evaluation::Behaviour
  ].freeze

  RESULTS = File.join(Evaluation::ROOT, "results")

  CORPUS = File.join(Evaluation::ROOT, "tmp", "corpus")

  def initialize(argv)
    @argv = argv
  end

  def status
    compared = option("--compare")
    return report(compared.split(",").map { JSON.parse(File.read(it)) }) if compared
    board = Evaluation::Board.new(option("--label") || "run", tool, checks, corpus).write(RESULTS)
    queue
    report([board])
  end

  private

  def report(boards)
    $stdout.puts(Evaluation::Comparison.new(boards).markdown)
    0
  end

  def option(flag)
    index = @argv.index(flag)
    @argv[index + 1] if index
  end

  def tool = @_tool ||= Evaluation::Tool.build(option("--hashira") || raise(ArgumentError, "eval/run --hashira PATH"))

  def chosen = (option("--suites") || [*SUITES.map { it::SUITE }, "corpus"].join(",")).split(",")

  def checks = SUITES.select { chosen.include?(it::SUITE) }.flat_map { it.build(tool).checks } + (corpus&.checks || [])

  def corpus
    return unless chosen.include?(Evaluation::Corpus::SUITE)
    @_corpus ||= Evaluation::Corpus.build(tool, option("--corpus") || CORPUS, draw)
  end

  def queue
    return unless corpus
    FileUtils.mkdir_p(draw.pending)
    corpus.precision.pending.group_by(&:kind).each { |kind, list| park(kind, list) }
  end

  def park(kind, list) = File.write(File.join(draw.pending, "#{kind}.yml"), YAML.dump(list.map(&:entry)))

  def draw = @_draw ||= Evaluation::Draw.build(option("--seed"))
end
