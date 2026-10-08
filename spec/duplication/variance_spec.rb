# frozen_string_literal: true

RSpec.describe(Hashira::Duplication::Variance) do
  def fragment(source)
    Hashira::Duplication::Fragment.new("f.rb", [Prism.parse(source).value.statements.body.first], Hashira::Duplication::Walks.new)
  end

  def variance(left, right) = described_class.new(fragment(left), fragment(right))
  it "is shape-only when every position that carries a name carries a different one" do
    expect(variance("a.map { |x| f(x) }", "b.each { |y| g(y) }").structural?).to(be(true))
  end

  it "is not shape-only when the sites share even one name" do
    expect(variance("a.map { |x| f(x) }", "a.map { |y| g(y) }").structural?).to(be(false))
  end

  it "names a method's own name as the difference when it is the only one" do
    definer = ->(name) { "def #{name}(x)\n  x.map { |y| f(y) }\nend" }
    expect(variance(definer["total"], definer["sum"]).kinds).to(eq([:renamed]))
    expect(variance(definer["total"], definer["total"]).kinds).to(be_empty)
  end

  it "sees renamed parameters and variables, including an op-write, as a different name" do
    expect(variance("def m(a) = f(a)", "def m(b) = f(b)").kinds).to(eq([:message]))
    expect(variance("@memo ||= load", "@cache ||= load").kinds).to(eq([:message]))
    expect(variance("total += 1", "total -= 1").kinds).to(eq([:message]))
  end

  it "sees a renamed constant assignment as a constant, and a changed pattern as a literal" do
    expect(variance("LIMIT = compute", "MAX = compute").kinds).to(eq([:constant]))
    expect(variance("s.match?(/\\Aa+/)", "s.match?(/\\Ab+/)").kinds).to(eq([:literal]))
  end

  it "sees safe navigation added to a call as a nil guard, not as a change in control flow" do
    expect(variance("client.trace_id", "client&.trace_id").kinds).to(eq([:nil_guard]))
    expect(variance("client&.trace_id", "client.trace_id").kinds).to(eq([:nil_guard]))
  end

  it "is not shape-only when the structure itself differs" do
    drifted = variance("a.map { |x| f(x) }", "b.each { |y| g(y) }.first")
    expect(drifted.structural?).to(be(false))
    expect(drifted.kinds).to(eq([:structure]))
  end

  it "reads a constant by what it points at, not the namespace it sits in" do
    shared = variance("a.grep(Prism::CallNode)", "b.grep_v(Prism::BlockParameterNode)")
    expect(shared.structural?).to(be(true))
    expect(variance("a.grep(Prism::CallNode)", "b.grep_v(Prism::CallNode)").structural?).to(be(false))
  end
end
