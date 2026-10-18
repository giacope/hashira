# frozen_string_literal: true

RSpec.describe(Hashira::Complexity::Indirection) do
  def traced(source, rules = Fixtures::NONE)
    within("lib/app/walk.rb" => source) do
      project = Hashira::Project.new(["lib/app"])
      parsed = Hashira::Trees.new(project)
      return Hashira::Complexity::Scores.new(project, parsed.all, rules, parsed).findings.select { it.kind == "indirection" }
    end
  end

  def walk(entry = "first(rows)", extra = "")
    <<~RUBY
      class Walk
        def run(rows) = #{entry}
        #{extra}
        private

        def first(rows) = second(rows.compact)

        def second(rows) = third(rows)

        def third(rows)
          rows.each { |row| puts(row) }
          tail(rows)
        end

        def tail(rows) = rows.size
      end
    RUBY
  end

  def chain(source) = traced(source).first.detail.chain

  def first(body) = walk.sub("def first(rows) = second(rows.compact)", "def first(rows)#{body}")

  it "counts the hollow helpers on the longest path from an entry, and lets the meaningful ones through for free" do
    finding = traced(walk).first
    expect([finding.package, finding.detail.to_h, finding.evidence]).to(
      eq(["Walk#run", { site: "walk.rb:2", chain: 3 }, ["first (line 6)", "second (line 8)", "tail (line 15)"]])
    )
  end

  it "says how many hollow helpers stand between the entry and its work, and what to do" do
    said = "Walk#run reaches its work through 3 hollow helpers, private one-liners called once that only pass a " \
      "call on (walk.rb:2). Inline them into their callers."
    expect(message(traced(walk).first)).to(eq(said))
  end

  it "flags a chain from exactly the threshold, and not one hop below it" do
    rules = [3, 4].map { Hashira::Config::Rules.parse({ "indirection" => { "threshold" => it } }, ["indirection"]) }
    expect(rules.map { traced(walk, it).size } + [traced(walk("third(rows)")).size]).to(eq([1, 0, 0]))
  end

  it "takes a body that decides, computes, runs a block or holds two statements for a meaningful helper" do
    bodies = [" = rows ? second(rows) : []", " = second(rows.compact.uniq)", " = second(rows.map { it })"]
    bodies += [" = second(rows) || 1", "\n  rows.compact\n  second(rows)\nend"]
    expect(bodies.map { chain(first(it)) } + [chain(walk.sub("rows.size", "1"))]).to(eq([2] * 6))
  end

  it "reports a chain once, from its entry, not again from the helpers inside it" do
    expect(traced(walk).map(&:package)).to(eq(["Walk#run"]))
  end

  it "takes a public method for an entry, which ends the chain" do
    second = "def second(rows) = third(rows)\n"
    open = walk.sub("  #{second}", "").sub("private\n", "#{second}private\n")
    expect(traced(open)).to(eq([]))
  end

  it "takes a method called twice, by symbol, through a receiver, or from elsewhere, for an entry" do
    twice = walk("first(rows) + second(rows)")
    named = walk("first(rows)", "before_action :second\n")
    received = walk("first(rows)", "def other(walk) = walk.second(1)\n")
    borrowed = "#{walk}class Other\n  include Walk\n  def go = second(1)\nend\n"
    expect([twice, named, received, borrowed].map { traced(it).map(&:package) }).to(eq([[]] * 4))
  end
end
