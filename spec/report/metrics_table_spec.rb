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
  it "keeps every row while the table fits" do
    analyze(hub(3), directories: ["app"], packaging: :namespace) do |_project, _census, graph|
      output = capture { described_class.new(graph).print }
      expect(output).to(include("Leaf3"))
      expect(output).not_to(include("leaf packages"))
    end
  end
  it "prints each fold under the coupling section" do
    files = FixtureHelper::RAILS_FILES.merge(FixtureHelper::SANDBOX_FILES)
    within(files) do
      pipeline = Hashira::Pipeline.new(Hashira::Project.new(["app"]), enabled: %i[coupling])
      view = Hashira::Report::View.new(
        project: pipeline.project, graph: pipeline.graph, complexity: nil, duplication: nil,
        hotspots: nil, findings: Hashira::CI::Accepted.new([]).screen(pipeline.findings)
      )
      output = capture { Hashira::Report::Text.new(view).print }
      expect(output).to(include("Folded (single-type classes joined to their base or domain):"))
      expect(output).to(include("  SandboxResource -> Sandbox (suffix)"))
    end
  end
end
