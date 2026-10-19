# frozen_string_literal: true

RSpec.describe(Hashira::Complexity::Fragmentation) do
  def split(files, rules = Fixtures::NONE)
    within(files) do
      project = Hashira::Project.new(["lib/app"])
      parsed = Hashira::Trees.new(project)
      return fragments(Hashira::Complexity::Scores.new(project, parsed.all, rules, parsed))
    end
  end

  def fragments(scores) = scores.findings.select { it.kind == "fragmentation" }

  def walk(entry = "def run(rows) = first(rows)", extra = "")
    <<~RUBY
      class Walk
        #{entry}
        #{extra}
        private

        def first(rows) = second(rows) + third(rows)

        def second(rows) = rows.size

        def third(rows) = fourth(rows)

        def fourth(rows) = rows.last
      end
    RUBY
  end

  def found(source, rules = Fixtures::NONE) = split({ "lib/app/walk.rb" => source }, rules)

  def stretched(line) = "def #{line[/def (\w+)/, 1]}(rows)\nlog\n#{line.split(" = ", 2).last}\nend"

  def limited(setting) = Hashira::Config::Rules.parse({ "fragmentation" => setting }, ["fragmentation"])

  it "reports an entry whose same-class helpers, four or more and two deep, average three and a half lines or less" do
    finding = found(walk).first
    detail = { site: "walk.rb:2", helpers: 4, lines: 1.0, depth: 3, path: %i[run first third fourth] }
    evidence = ["first (line 6)", "second (line 8)", "third (line 10)", "fourth (line 12)"]
    expect([finding.package, finding.detail.to_h, finding.evidence]).to(eq(["Walk#run", detail, evidence]))
  end

  it "says how many helpers, how short, how deep, and what to do" do
    said = "Walk#run spreads its work over 4 same-class helpers averaging 1.0 lines a method, 3 deep " \
      "(run → first → third → fourth) (walk.rb:2). Merge the helpers that only move data into the entry; " \
      "keep named predicates."
    expect(message(found(walk).first)).to(eq(said))
  end

  it "moves both limits under checks, flagging from exactly each limit and not past it" do
    settings = [{ "helpers" => 4 }, { "helpers" => 5 }, { "lines" => 1 }, { "lines" => 0.9 }]
    expect(settings.map { found(walk, limited(it)).size }).to(eq([1, 0, 1, 0]))
  end

  it "needs a path two deep, and methods short on average" do
    flat = "def run(rows) = [first(rows), second(rows), third(rows), fourth(rows)]"
    shallow = walk(flat).sub("def first(rows) = second(rows) + third(rows)", "def first(rows) = rows")
    long = walk.gsub(/def (\w+)\(rows\) = (.+)$/) { stretched(it) }
    two = walk.sub("third(rows)", "third(rows) + fourth(rows)").sub("= fourth(rows)", "= rows")
    expect([two, shallow, long].map { found(it).size }).to(eq([1, 0, 0]))
  end

  it "counts a method's lines without comments or blank lines, and with the heredoc it opens" do
    padded = walk.sub("def second(rows) = rows.size", "def second(rows)\n=begin\nnote\n=end\n  rows.size # why\n\nend")
      .sub("def fourth(rows) = rows.last", "def fourth(rows) = <<TEXT\ndone\n# kept\nTEXT")
    expect(found(padded).first.detail.lines).to(eq(2.0))
  end

  it "takes only a public method for an entry, not initialize, and leaves helpers called by name in" do
    hidden = walk("", "private\ndef run(rows) = first(rows)\npublic")
    built = walk("def initialize(rows) = first(rows)")
    named = walk("def run(rows) = send(:first, rows)")
    tagged = walk("def run(rows) = tag(:first)")
    expect([hidden, built, named, tagged].map { found(it).map(&:package) }).to(eq([[], [], ["Walk#run"], []]))
  end

  it "links instance methods to instance methods and class methods to class methods, across a reopened class" do
    lifted = walk("def self.run(rows) = first(rows)")
    more = "class Walk\n  def go(rows) = method(:first)\nend\n"
    reopened = { "lib/app/walk.rb" => walk, "lib/app/walk/more.rb" => more }
    expect([found(lifted).map(&:package), split(reopened).map(&:package)]).to(eq([[], %w[Walk#run Walk#go]]))
  end

  it "counts a helper reached along two paths once" do
    twice = walk.sub("def third(rows) = fourth(rows)", "def third(rows) = fourth(rows) + second(rows)")
    expect(found(twice).first.detail.helpers).to(eq(4))
  end

  it "leaves named predicates out of the count, and lists them as not counted" do
    asked = walk.gsub("fourth(rows)", "fourth?(rows)")
    fifth = asked.sub("def second(rows) = rows.size", "def second(rows) = fifth(rows)\n  def fifth(rows) = rows.size")
    evidence = ["first (line 6)", "second (line 8)", "fifth (line 9)", "third (line 11)"]
    evidence << "fourth? (line 13) (predicate, not counted)"
    expect([found(asked), found(fifth).map { [it.detail.helpers, it.evidence] }]).to(eq([[], [[4, evidence]]]))
  end
end
