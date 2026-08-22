# frozen_string_literal: true

RSpec.describe(Hashira::Report::MetricsTable) do
  def hub(count)
    (1..count).to_h { ["app/models/leaf#{it}.rb", "class Leaf#{it}\n  def a = 1\nend\n"] }
      .merge("app/models/hub.rb" => "class Hub\n#{(1..count).map { "  def use#{it} = Leaf#{it}.new\n" }.join}end\n")
  end
  it "collapses inert leaf packages when the table grows long" do
    analyze(hub(26), directories: ["app"], packaging: :namespace) do |_project, _census, graph|
      output = capture { described_class.new(graph).print }
      expect(output).to(include("Hub"))
      expect(output).not_to(include("Leaf3 "))
      expect(output).to(include("+ 26 single-type leaf packages"))
    end
  end

  it "keeps a depended-upon single-type package visible past the limit" do
    files = hub(26).merge(
      "app/models/shared.rb" => "class Shared\n  def s = 1\nend\n",
      "app/models/extra.rb" => "class Extra\n  def e = Shared.new\nend\n",
      "app/models/other.rb" => "class Other\n  def o = Shared.new\nend\n"
    )
    analyze(files, directories: ["app"], packaging: :namespace) do |_project, _census, graph|
      output = capture { described_class.new(graph).print }
      expect(output).to(include("Shared"))
      expect(output).to(include("single-type leaf packages"))
      expect(output).not_to(include("Leaf3 "))
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

  it "prints each fold under the coupling section" do
    files = Fixtures::RAILS_FILES.merge(Fixtures::SANDBOX_FILES)
    within(files) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["app"]), Hashira::Plan.new(enabled: %i[coupling]))
      view = Hashira::Report::View.new(
        project: pipeline.project, files: pipeline.snapshot.size, graph: pipeline.graph,
        complexity: nil, duplication: nil,
        hotspots: nil, findings: Hashira::CI::Accepted.new([]).screen(pipeline.findings)
      )
      output = capture { Hashira::Report::Text.new(view).print }
      expect(output).to(include("Folded (single-type classes joined to their base or domain):"))
      expect(output).to(include("  SandboxResource -> Sandbox (suffix)"))
    end
  end
end
