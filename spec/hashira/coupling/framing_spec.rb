# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Framing, :aggregate_failures) do
  def unframed(source)
    within("lib/app/base.rb" => source) do
      project = Hashira::Project.new(["lib/app"])
      graph = outcome(Hashira::Pipeline.build(project)).graph
      framed(Hashira::Coupling::Surface.new(project.paths, graph.trees, graph.census), graph)
    end
  end

  def framed(surface, graph)
    marks = Hashira::Coupling::Mentions.new(graph.trees).marks(graph.census, surface.openings)
    framing = described_class.new(surface.heritage, Fakes::Hosting.new([["Base"]]), surface.methods, marks)
    surface.methods.reject { framing.framed?(it) }.map(&:to_a)
  end

  it "frames a method whose ancestor's method of the same name and kind is hooked, and no other" do
    source = <<~RUBY
      module App
        class Base
          def self.run = 1
          def run = 2
          def walk = 3
        end

        class Child < Base
          def run = 3
          def self.run = 4
          def self.walk = 5
        end
      end
    RUBY
    expect(unframed(source)).to(eq([[["Child"], ".", "walk"]]))
  end
end
