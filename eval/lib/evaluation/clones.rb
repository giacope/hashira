# frozen_string_literal: true

class Evaluation::Clones
  SUITE = "duplication"

  QUIET = %w[--json --skip coupling,complexity,smells].freeze

  RANGE = /\A(?<file>.+):(?<first>\d+)-(?<last>\d+)\z/

  TOGETHER = { true => :together, false => :apart }.freeze

  def self.build(tool) = new(tool, File.join(Evaluation::CASES, "duplication"))

  def initialize(tool, root)
    @tool = tool
    @root = root
  end

  def checks = Evaluation::Sandbox.expectations(@root).flat_map { verdicts(it) }

  private

  def verdicts(fixture)
    expect = YAML.safe_load_file(File.join(fixture, "expect.yml"))
    outcome = Evaluation::Sandbox.copy(File.join(fixture, "project")) { @tool.call(it, expect.fetch("args", []) + QUIET) }
    found = outcome.kinds("duplication").map { |finding| finding["evidence"].map { span(it) } }
    judged(File.basename(fixture), expect, found)
  end

  def judged(name, expect, found)
    [
      *expect.fetch("clusters", []).map { verdict(name, it, found, :together) },
      *expect.fetch("apart", []).map { verdict(name, it, found, :apart) }, *counted(name, expect, found)
    ]
  end

  def counted(name, expect, found)
    wanted = expect["count"]
    wanted ? [Evaluation::Check.of(SUITE, "#{name}: findings", wanted, found.size)] : []
  end

  def verdict(name, sites, found, wanted)
    together = found.any? { |cluster| sites.all? { covered?(cluster, it) } }
    Evaluation::Check.of(SUITE, "#{name}: #{sites.join(" + ")}", wanted, TOGETHER.fetch(together))
  end

  def span(range)
    parts = RANGE.match(range)
    [parts[:file], Integer(parts[:first])..Integer(parts[:last])]
  end

  def covered?(cluster, site)
    file, line = site.split(":")
    cluster.any? { |path, lines| path == file && lines.cover?(Integer(line)) }
  end
end
