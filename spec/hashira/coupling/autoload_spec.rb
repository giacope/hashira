# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Autoload) do
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

  it "adds none outside a Rails app" do
    expect(roots(files)).to(eq([%w[Billing], %w[Billing Plan], %w[Last]]))
  end
end
