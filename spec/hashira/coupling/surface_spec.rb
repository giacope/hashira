# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Surface, :aggregate_failures) do
  def forebears(source)
    within("lib/app/base.rb" => source) do
      project = Hashira::Project.new(["lib/app"])
      graph = outcome(Hashira::Pipeline.build(project)).graph
      surface = described_class.new(project, graph.trees, graph.census)
      surface.methods.select { it.owner == ["Child"] }.to_h { [it.name, surface.forebears(it).map(&:name)] }
    end
  end

  it "takes a method's forebears from its ancestors' methods of the same name and kind" do
    source = <<~RUBY
      module App
        class Base
          def self.run = 1
          def run = 2
        end

        class Child < Base
          def run = 3
          def self.run = 4
        end
      end
    RUBY
    expect(forebears(source)).to(eq("App::Child#run" => ["App::Base#run"], "App::Child.run" => ["App::Base.run"]))
  end
end
