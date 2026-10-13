# frozen_string_literal: true

RSpec.describe(Hashira::Complexity::Indirection) do
  def traced(source, rules = Fixtures::NONE)
    files = { "lib/app/walk.rb" => source }
    within(files) do
      project = Hashira::Project.new(["lib/app"])
      trees = project.files.to_h { [it, Prism.parse_file(it).value] }
      return Hashira::Complexity::Scores.new(project, trees, rules).findings.select { it.kind == "indirection" }
    end
  end

  def walk(entry = "rows.each { |row| check(row) }", extra = "")
    <<~RUBY
      class Walk
        def run(rows)
          #{entry}
        end
        #{extra}
        private

        def check(row)
          if row.a
            if row.b
              mark(row)
            end
          end
        end

        def mark(row)
          row.c ? 1 : 2
          while row.d do end
          row.f if row.e
        end
      end
    RUBY
  end

  it "reports a trace once, from its entry, not again from the helpers inside it" do
    expect(traced(walk).map(&:package)).to(eq(["Walk#run"]))
  end

  it "flags a trace from exactly the threshold, and not one point below it" do
    rules = [17, 18].map { Hashira::Config::Rules.parse({ "indirection" => { "threshold" => it } }, ["indirection"]) }
    expect(rules.map { traced(walk, it).size }).to(eq([1, 0]))
  end

  it "scores a method with its single-use helpers read in place, each at the nesting of its call" do
    finding = traced(walk).first
    expect([finding.detail.to_h, finding.evidence]).to(
      eq([{ site: "walk.rb:2", cognitive: 17, own: 0, helpers: 2, depth: 2 }, ["check (line 8)", "mark (line 16)"]])
    )
  end

  it "says what the trace scores read in place and by itself, and what to do" do
    said = "Walk#run scores cognitive 17 with its 2 single-use helpers (2 deep) read in place, 0 by itself " \
      "(walk.rb:2). Inline the helpers that only move code, and reduce the logic itself."
    expect(message(traced(walk).first)).to(eq(said))
  end

  it "takes a helper called twice, by symbol, through a receiver, or from another class for an abstraction" do
    twice = walk("rows.each { |row| check(row) }\n    check(rows.first)")
    named = walk("rows.each { |row| check(row) }", "before_action :check\n")
    received = walk("rows.each { |row| check(row) }", "def other(walk) = walk.check(1)\n")
    borrowed = "#{walk}class Other\n  include Walk\n  def go = check(1)\nend\n"
    expect([twice, named, received, borrowed].map { traced(it).map(&:package) }).to(eq([["Walk#check"]] * 4))
  end

  it "leaves a method already over the complexity threshold to complexity" do
    tangled = walk("if rows\n if rows.a\n if rows.b\n if rows.c\n check(rows)\n end\n end\n end\n end")
    expect(traced(tangled)).to(eq([]))
  end
end
