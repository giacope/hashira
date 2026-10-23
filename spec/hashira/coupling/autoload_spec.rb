# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Autoload, :aggregate_failures) do
  def roots(files)
    within(files) do
      project = Hashira::Project.new(%w[app])
      return described_class.new(project, project.files.to_h { [it, Hashira::Trees.parse(it)] }).roots.to_a.sort
    end
  end

  def files
    {
      "app/models/concerns/billing/plan.rb" => "module Billing\n  module Plan; end\nend\n",
      "app/wizards/steps/review/last.rb" => "class Last; end\n"
    }
  end

  it "adds the namespaces Zeitwerk makes of the folders under an app directory, below concerns too" do
    expect(roots(files.merge("config/application.rb" => "")))
      .to(eq([%w[Billing], %w[Billing Plan], %w[Last], %w[Steps], %w[Steps Review]]))
  end

  it "takes no root from the owner a DSL block gives its defs" do
    expect(roots("app/x.rb" => "module X\n  configure do\n    def tuned = 1\n  end\nend\n")).to(eq([%w[X]]))
  end

  it "adds none outside a Rails app" do
    expect(roots(files)).to(eq([%w[Billing], %w[Billing Plan], %w[Last]]))
  end
end
