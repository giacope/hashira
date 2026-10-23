# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Definitions, :aggregate_failures) do
  def paths
    project = Hashira::Project.new(["lib/app"])
    described_class.new(project, project.files.to_h { [it, Hashira::Trees.parse(it)] }).map { |_node, path| path }
  end

  it "counts no constant for the owner a DSL block gives its defs" do
    files = { "lib/app/x.rb" => "module App\n  Feature.define(:x) do\n    def tuned = 1\n  end\nend\n" }
    expect(within(files) { paths }).to(eq([%w[App]]))
  end
end
