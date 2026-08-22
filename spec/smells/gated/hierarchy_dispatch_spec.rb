# frozen_string_literal: true

RSpec.describe(Hashira::Smells::Gated::HierarchyDispatch) do
  def asking(files, yaml = Fixtures::ALL_FACTS) = gated(files, yaml, "hierarchy_dispatch")

  def kin(body) = Fixtures.zoned("Base", "def call = 1").merge(Fixtures.zoned("Heir", body, "Base"))

  def siblings(body) = kin("def call = 2").merge(Fixtures.zoned("Twin", body, "Base"))

  def probing = siblings("def pick(other) = other.is_a?(Heir)")

  it "names the method that asks about its own family" do
    expect(asking(probing).map(&:package)).to(eq(["App::Zone::Twin#pick"]))
  end

  it "says which class it asked about" do
    expect(message(asking(probing).first)).to(
      include("asks whether something is 'App::Zone::Heir', a class in its own family")
    )
  end

  it "catches kind_of? and instance_of? too" do
    expect(asking(siblings("def pick(other) = other.kind_of?(Heir)")).size).to(eq(1))
  end

  it "catches a case that arms on a relative" do
    body = "def pick(other)\n  case other\n  when Heir then 1\n  else 2\n  end\nend"
    expect(asking(siblings(body)).size).to(eq(1))
  end

  it "catches a base asking about its own subclass" do
    files = Fixtures.zoned("Base", "def pick(other) = other.is_a?(Heir)")
    expect(asking(files.merge(Fixtures.zoned("Heir", "def call = 1", "Base"))).map(&:package)).to(
      eq(["App::Zone::Base#pick"])
    )
  end

  it "says nothing about a class outside the family" do
    files = siblings("def pick(other) = other.is_a?(Stranger)").merge(Fixtures.zoned("Stranger", "def call = 1"))
    expect(asking(files)).to(be_empty)
  end

  it "says nothing about a bare type test with nothing to test against" do
    expect(asking(siblings("def pick(other) = other.is_a?"))).to(be_empty)
  end

  it "does not spin when two classes claim each other as parent" do
    files = Fixtures.zoned("Base", "def pick(other) = other.is_a?(Heir)", "Heir")
    expect(asking(files.merge(Fixtures.zoned("Heir", "def call = 1", "Base"))).size).to(eq(1))
  end

  it "says nothing about a class the project does not define" do
    expect(asking(siblings("def pick(other) = other.is_a?(ActiveRecord::Base)"))).to(be_empty)
  end

  it "says nothing about a class asking after itself" do
    expect(asking(kin("def pick(other) = other.is_a?(Heir)"))).to(be_empty)
  end

  it "says nothing when the project declares no constraints" do
    expect(asking(probing, nil)).to(be_empty)
  end

  it "says nothing when no_const_missing is missing from the declarations" do
    expect(asking(probing, Fixtures::THREE_FACTS)).to(be_empty)
  end
end
