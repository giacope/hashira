# frozen_string_literal: true

RSpec.describe(Hashira::Duplication::Variance) do
  def fragment(source)
    Hashira::Duplication::Fragment.new("f.rb", [Prism.parse(source).value.statements.body.first])
  end

  def variance(left, right) = described_class.new(fragment(left), fragment(right))
  it "is shape-only when every position that carries a name carries a different one" do
    expect(variance("a.map { |x| f(x) }", "b.each { |y| g(y) }").structural?).to(be(true))
  end

  it "is not shape-only when the sites share even one name" do
    expect(variance("a.map { |x| f(x) }", "a.map { |y| g(y) }").structural?).to(be(false))
  end

  it "ignores a method's own name, which labels the fragment rather than sitting inside it" do
    definer = ->(name) { "def #{name}(x)\n  x.map { |y| f(y) }\nend" }
    expect(variance(definer["total"], definer["sum"]).kinds).to(be_empty)
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
