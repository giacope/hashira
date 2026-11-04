# frozen_string_literal: true

RSpec.describe(Hashira::Report::MetricsTable, :aggregate_failures) do
  def hub(count)
    (1..count).to_h { ["app/models/leaf#{it}.rb", "class Leaf#{it}\n  def a = 1\nend\n"] }
      .merge("app/models/hub.rb" => "class Hub\n#{(1..count).map { "  def use#{it} = Leaf#{it}.new\n" }.join}end\n")
  end
  def table(files)
    analyze(files, directories: ["app"], packaging: :namespace) do |*, graph|
      capture { described_class.new(graph).print }
    end
  end

  it "collapses inert leaf packages when the table grows long" do
    expect(table(hub(26))).to(include("Hub", "+ 26 single-type leaf packages").and(exclude("Leaf3 ")))
  end

  it "keeps a depended-upon single-type package visible past the limit" do
    files = hub(26).merge(
      "app/models/shared.rb" => "class Shared\n  def s = 1\nend\n",
      "app/models/extra.rb" => "class Extra\n  def e = Shared.new\nend\n",
      "app/models/other.rb" => "class Other\n  def o = Shared.new\nend\n"
    )
    expect(table(files)).to(include("Shared", "single-type leaf packages").and(exclude("Leaf3 ")))
  end

  it "keeps a package holding several types visible past the limit" do
    files = hub(26).merge(
      "app/models/pair.rb" => "module Pair\n  class One\n    def a = 1\n  end\n  class Two\n    def b = 2\n  end\nend\n"
    )
    expect(table(files)).to(match(/^Pair\s+2\s+0\s+0/).and(include("+ 26 single-type leaf packages")))
  end

  it "hides no leaf when the table exactly fits the cap" do
    analyze(hub(3), directories: ["app"], packaging: :namespace) do |_project, _census, graph|
      output = capture { described_class.new(graph, top: 4).print }
      expect(output).to(include("Leaf3"))
      expect(output).not_to(include("leaf packages"))
    end
  end

  def chain(count)
    (1..count).to_h do |n|
      ["app/models/p#{n}.rb", "class P#{n}\n  def go = P#{(n % count) + 1}.new\nend\n"]
    end
  end
  it "caps the rows at --top and says how many it withheld" do
    analyze(chain(5), directories: ["app"], packaging: :namespace) do |_project, _census, graph|
      output = capture { described_class.new(graph, top: 2).print }
      expect(output).to(include("… and 3 more — raise the cap with --top, or read them all with --json"))
      expect(output.lines.count { it.match?(/^P\d/) }).to(eq(2))
    end
  end

  it "says nothing about withheld rows when every row fits" do
    analyze(hub(3), directories: ["app"], packaging: :namespace) do |_project, _census, graph|
      expect(capture { described_class.new(graph).print }).not_to(include("more —"))
    end
  end

  it "keeps every row while the table fits" do
    analyze(hub(3), directories: ["app"], packaging: :namespace) do |_project, _census, graph|
      output = capture { described_class.new(graph).print }
      expect(output).to(include("Leaf3"))
      expect(output).not_to(include("leaf packages"))
    end
  end

  def coupling_report
    project = Hashira::Project.new(["app"])
    pipeline = Hashira::Pipeline.build(project, Hashira::Config::Rules.new({}), Fixtures::FLAT, Hashira::Selection.new(%i[coupling]))
    findings = Hashira::CI::Accepted.new([]).screen(kept(pipeline))
    verdicts = Hashira::Report::View::Verdicts.new(findings, Fixtures::CLEAR, Fixtures::JUDGED)
    analyses = Hashira::Report::View::Analyses.new([outcome(pipeline).graph], [], [], [])
    view = Hashira::Report::View.new(project, analyses, verdicts)
    capture { view.text.print }
  end

  it "prints each fold under the coupling section" do
    expect(within(Fixtures::RAILS_FILES.merge(Fixtures::SANDBOX_FILES)) { coupling_report }).to(
      include(
        "Folded (packages joined to the one they belong to):", "  SandboxPolicy -> Sandbox (suffix)\n\nFindings ("
      )
    )
  end
end
