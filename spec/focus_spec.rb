# frozen_string_literal: true

RSpec.describe(Hashira::Focus) do
  def finding(package, site, evidence: [])
    Hashira::Analysis::Finding.new(kind: "cycle", package:, detail: { site: }, evidence:)
  end

  def focused(paths, &)
    within(Fixtures::CYCLIC_FILES) { yield(described_class.new(Hashira::Project.new(["lib/app"]), paths)) }
  end

  it "narrows nothing when no file was named" do
    focused([]) { |focus| expect(focus.narrowing?).to(be(false)) }
  end

  it "passes every finding through when no file was named" do
    focused([]) { |focus| expect(focus.narrow([finding("alpha", "alpha/one.rb:3")]).size).to(eq(1)) }
  end

  it "keeps the findings sited in a named file and drops the rest" do
    focused(["lib/app/alpha/one.rb"]) do |focus|
      kept = finding("App::Alpha::One#call", "alpha/one.rb:4")
      dropped = finding("App::Beta::Two#call", "beta/two.rb:4")
      expect(focus.narrow([kept, dropped])).to(eq([kept]))
    end
  end

  it "keeps a finding a named file only appears in as evidence" do
    focused(["lib/app/beta/two.rb"]) do |focus|
      cycle = finding("alpha", nil, evidence: ["alpha/one.rb:4: Beta::Two", "beta/two.rb:4: Alpha::One"])
      expect(focus.narrow([cycle])).to(eq([cycle]))
    end
  end

  it "names a file the duplication findings carry in place of a package" do
    focused(["lib/app/core/util.rb"]) do |focus|
      clone = Hashira::Analysis::Finding.new(kind: "duplication", package: "core/util.rb:3", evidence: [])
      expect(focus.narrow([clone])).to(eq([clone]))
    end
  end

  it "still counts as narrowing when the named file is outside the analyzed directories" do
    focused(["spec/app_spec.rb"]) { |focus| expect(focus.narrowing?).to(be(true)) }
  end

  it "ignores a file outside the analyzed directories rather than refusing the run" do
    focused(["spec/app_spec.rb"]) { |focus| expect(focus.narrow([finding("alpha", "alpha/one.rb:4")])).to(eq([])) }
  end
end
