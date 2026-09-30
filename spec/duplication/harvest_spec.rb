# frozen_string_literal: true

RSpec.describe(Hashira::Duplication::Harvest) do
  def ranges(sources) = fragments(sources).map(&:range)
  it "extracts every contiguous run of sibling statements, down to one" do
    ranges = ranges("m.rb" => "def m\n a\n b(1)\n c\nend\n").uniq
    expect(ranges).to(
      contain_exactly(
        "m.rb:2-2", "m.rb:3-3", "m.rb:4-4",
        "m.rb:2-3", "m.rb:3-4", "m.rb:2-4", "m.rb:1-5"
      )
    )
  end

  it "extracts a one-line method, which has no statement run of its own" do
    fragment = fragments("m.rb" => "def m = a\n").find { it.types.first == :def_node }
    expect(fragment.range).to(eq("m.rb:1-1"))
    expect(fragment.types).to(eq(%i[def_node statements_node call_node]))
  end

  it "extracts a when arm and a rescue clause as whole nodes" do
    ranges = ranges("m.rb" => "case x\nwhen 1 then a\nend\nbegin\n b\nrescue Foo\n c\nend\n")
    expect(ranges).to(include("m.rb:2-2", "m.rb:6-7"))
  end

  it "skips a sequence of identically shaped statements — a list, not a clone" do
    ranges = ranges("m.rb" => "require \"a\"\nrequire \"b\"\nrequire \"c\"\nrequire \"d\"\n")
    expect(ranges).to(be_empty)
  end

  it "skips the list even when a statement of another shape follows it" do
    ranges = ranges("m.rb" => "require \"a\"\nrequire \"b\"\nrequire \"c\"\ndef m\nend\n").uniq
    expect(ranges).to(contain_exactly("m.rb:4-5"))
  end

  it "never takes a type definition as a fragment — its body is windowed on its own" do
    source = "require \"x\"\nmodule M\n class C\n  def m\n   a(1)\n  end\n end\n class << self\n  b(2)\n end\nend\n"
    ranges = ranges("m.rb" => source).uniq
    expect(ranges).to(contain_exactly("m.rb:1-1", "m.rb:4-6", "m.rb:5-5", "m.rb:9-9"))
  end

  it "skips a run of identically shaped when arms — a dispatch table is a list" do
    table = "case x\nwhen :a then run(1)\nwhen :b then run(2)\nwhen :c then run(3)\nwhen :d then stop(x, 4)\nend\n"
    arms = fragments("m.rb" => table).select { it.types.first == :when_node }
    expect(arms.map(&:range)).to(eq(["m.rb:5-5"]))
  end

  it "keeps when arms that are not a list, each as a whole" do
    arms = fragments("m.rb" => "case x\nwhen :a then run(1)\nwhen :b then run(2)\nend\n")
    arms = arms.select { it.types.first == :when_node }
    expect(arms.map(&:range)).to(eq(["m.rb:2-2", "m.rb:3-3"]))
  end

  it "does not start a window on a bare visibility line that heads a method" do
    source = "class C\n def a = x(1)\n private\n def b = y(2)\n audited\n z(3)\nend\n"
    starts = fragments("m.rb" => source).reject { it.mass == 1 }.map(&:line).uniq
    expect(starts).to(include(2, 4, 5))
    expect(starts).not_to(include(3))
  end

  it "ends a fragment on the closing line of a heredoc it carries" do
    fragment = fragments("m.rb" => "def m\n emit(<<~SQL, 1)\n  select 1\n SQL\nend\n").find { it.line == 2 }
    expect(fragment.range).to(eq("m.rb:2-4"))
  end

  it "windows each side of a list on its own, never across it" do
    body = "def m\n a(1)\n b = 2\n c(:x)\n c(:y)\n c(:z)\n d(1, 2)\n e = f\nend\n"
    ranges = ranges("m.rb" => body).uniq
    expect(ranges).to(
      contain_exactly(
        "m.rb:2-2", "m.rb:3-3", "m.rb:2-3",
        "m.rb:7-7", "m.rb:8-8", "m.rb:7-8", "m.rb:1-9"
      )
    )
  end

  it "caps window length so the fragment count stays linear in the sequence length" do
    body = (1..40).map { |i| i.even? ? "a#{i}(#{i})" : "b#{i} = c#{i}" }.join("\n ")
    count = fragments("m.rb" => "def m\n #{body}\nend\n").size
    expect(count).to(be < 450)
  end

  it "exposes a fragment's type sequence, location, and range" do
    fragment = fragments("m.rb" => "def m\n a\n b(1)\nend\n").find { it.range == "m.rb:2-3" }
    expect(fragment.types).to(eq(%i[call_node call_node arguments_node integer_node]))
    expect(fragment.location).to(eq("m.rb:2"))
    expect(fragment.range).to(eq("m.rb:2-3"))
    expect(fragment.rank).to(eq(["m.rb", 2]))
  end

  it "knows when two fragments overlap within the same file" do
    early, late = fragments("m.rb" => "def m\n a\n b(1)\n c\nend\n").select { |f| f.mass == 4 }.sort_by(&:line)
    expect(early.overlaps?(late)).to(be(true))
  end

  it "knows when a fragment lies within another, even one sharing its first or last line" do
    all = fragments("m.rb" => "def m\n a(1)\n b = 2\n c(:x)\nend\n")
    body, head, tail, whole = %w[m.rb:2-4 m.rb:2-3 m.rb:3-4 m.rb:1-5].map { |range| all.find { it.range == range } }
    expect([head, tail, body].map { it.within?([body]) }).to(eq([true, true, true]))
    expect(whole.within?([body])).to(be(false))
    expect(fragments("n.rb" => "def m\n a(1)\n b(2)\n c(3)\nend\n").first.within?([body])).to(be(false))
  end

  it "treats fragments in different files as non-overlapping" do
    here = fragments("a.rb" => "def m\n a\n b(1)\nend\n").first
    there = fragments("b.rb" => "def m\n a\n b(1)\nend\n").first
    expect(here.overlaps?(there)).to(be(false))
  end

  it "walks each statement's subtree once, however many windows and whole nodes include it" do
    walked = []
    allow(Hashira::Analysis::NodeWalk).to(
      receive(:collect).and_wrap_original do |walk, node|
        walked << node
        walk.call(node)
      end
    )
    kinds = fragments("m.rb" => "class M\n  def m\n    a\n    b(1) if c\n  end\n  def n = d\nend\n").map(&:types)
    expect(walked.map(&:object_id).tally.values.max).to(eq(1))
    expect(kinds).to(include(%i[def_node statements_node call_node]))
  end
end
