# frozen_string_literal: true

RSpec.describe(Hashira::Focus) do
  def finding(package, sources)
    Hashira::Analysis::Finding.new(kind: "cycle", package:, detail: { site: package }, evidence: [], sources:)
  end

  def focused(paths, &)
    within(Fixtures::CYCLIC_FILES) { yield(described_class.new(Hashira::Project.new(["lib/app"]), paths)) }
  end

  it "narrows nothing when no file was named" do
    focused([]) { |focus| expect(focus.narrowing?).to(be(false)) }
  end

  it "passes every finding through when no file was named" do
    focused([]) { |focus| expect(focus.narrow([finding("alpha", ["alpha/one.rb"])]).size).to(eq(1)) }
  end

  it "keeps the findings sourced in a named file and drops the rest" do
    focused(["lib/app/alpha/one.rb"]) do |focus|
      kept = finding("App::Alpha::One#call", ["alpha/one.rb"])
      dropped = finding("App::Beta::Two#call", ["beta/two.rb"])
      expect(focus.narrow([kept, dropped])).to(eq([kept]))
    end
  end

  it "keeps a finding that names the file among several sources" do
    focused(["lib/app/beta/two.rb"]) do |focus|
      cycle = finding("alpha", ["alpha/one.rb", "beta/two.rb"])
      expect(focus.narrow([cycle])).to(eq([cycle]))
    end
  end

  it "still counts as narrowing when the named file is outside the analyzed directories" do
    focused(["spec/app_spec.rb"]) { |focus| expect(focus.narrowing?).to(be(true)) }
  end

  it "ignores a file outside the analyzed directories rather than refusing the run" do
    focused(["spec/app_spec.rb"]) do |focus|
      expect(focus.narrow([finding("alpha", ["alpha/one.rb"])])).to(eq([]))
    end
  end

  it "reads the file a finding names from its own record, not from the words it prints" do
    focused(["lib/app/core/util.rb"]) do |focus|
      quoted = finding("App::Alpha::One#call", ["alpha/one.rb"]).with(evidence: ["core/util.rb:3: mentioned"])
      expect(focus.narrow([quoted])).to(eq([]))
    end
  end
end
