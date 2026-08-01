# frozen_string_literal: true

RSpec.describe(Hashira::Duplication::Extractor) do
  def ranges(sources) = fragments(sources).map(&:range)
  it "extracts every contiguous run of sibling statements, down to one" do
    ranges = ranges("m.rb" => "def m\n a\n b(1)\n c\nend\n").uniq
    # a lone statement can be a clone on its own — a long expression in a block
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
    ranges = ranges("m.rb" => "require \"a\"\nrequire \"b\"\nrequire \"c\"\nmodule M\nend\n").uniq
    # no window reaches into the list, so the module is weighed on its own mass —
    # a list row next door is not evidence that the module is a copy
    expect(ranges).to(contain_exactly("m.rb:4-5"))
  end
  it "windows each side of a list on its own, never across it" do
    body = "def m\n a(1)\n b = 2\n c(:x)\n c(:y)\n c(:z)\n d(1, 2)\n e = f\nend\n"
    # the three c calls are a list; the statements before and after it still pair
    # up among themselves, but no window spans the list to borrow its mass
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
    # 40 statements: capped at 12 that is 414 windows, uncapped it would be 820
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
  it "treats fragments in different files as non-overlapping" do
    here = fragments("a.rb" => "def m\n a\n b(1)\nend\n").first
    there = fragments("b.rb" => "def m\n a\n b(1)\nend\n").first
    expect(here.overlaps?(there)).to(be(false))
  end
end
