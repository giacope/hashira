# frozen_string_literal: true

RSpec.describe Hashira::Duplication::Extractor do
  def ranges_for(sources) = fragments_for(sources).map(&:range)

  it "extracts every contiguous run of sibling statements, down to one" do
    ranges = ranges_for("m.rb" => "def m\n a\n b(1)\n c\nend\n").uniq

    # a lone statement can be a clone on its own — a long expression in a block
    expect(ranges).to contain_exactly("m.rb:2-2", "m.rb:3-3", "m.rb:4-4",
                                      "m.rb:2-3", "m.rb:3-4", "m.rb:2-4", "m.rb:1-5")
  end

  it "extracts a one-line method, which has no statement run of its own" do
    fragment = fragments_for("m.rb" => "def m = a\n").find { it.types.first == :def_node }

    expect(fragment.range).to eq("m.rb:1-1")
    expect(fragment.types).to eq(%i[def_node statements_node call_node])
  end

  it "extracts a when arm and a rescue clause as whole nodes" do
    ranges = ranges_for("m.rb" => "case x\nwhen 1 then a\nend\nbegin\n b\nrescue Foo\n c\nend\n")

    expect(ranges).to include("m.rb:2-2", "m.rb:6-7")
  end

  it "skips a sequence of identically shaped statements — a list, not a clone" do
    ranges = ranges_for("m.rb" => "require \"a\"\nrequire \"b\"\nrequire \"c\"\nrequire \"d\"\n")

    expect(ranges).to be_empty
  end

  it "caps window length so the fragment count stays linear in the sequence length" do
    body = (1..40).map { |i| i.even? ? "a#{i}(#{i})" : "b#{i} = c#{i}" }.join("\n ")
    count = fragments_for("m.rb" => "def m\n #{body}\nend\n").size

    # 40 statements: capped at 12 that is 414 windows, uncapped it would be 820
    expect(count).to be < 450
  end

  it "exposes a fragment's type sequence, location, and range" do
    fragment = fragments_for("m.rb" => "def m\n a\n b(1)\nend\n").find { it.range == "m.rb:2-3" }

    expect(fragment.types).to eq(%i[call_node call_node arguments_node integer_node])
    expect(fragment.location).to eq("m.rb:2")
    expect(fragment.range).to eq("m.rb:2-3")
    expect(fragment.sort_key).to eq(["m.rb", 2])
  end

  it "knows when two fragments overlap within the same file" do
    early, late = fragments_for("m.rb" => "def m\n a\n b(1)\n c\nend\n").select { |f| f.mass == 4 }.sort_by(&:line)

    expect(early.overlaps?(late)).to be(true)
  end

  it "treats fragments in different files as non-overlapping" do
    here = fragments_for("a.rb" => "def m\n a\n b(1)\nend\n").first
    there = fragments_for("b.rb" => "def m\n a\n b(1)\nend\n").first

    expect(here.overlaps?(there)).to be(false)
  end
end
