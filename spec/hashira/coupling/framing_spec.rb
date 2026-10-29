# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Framing, :aggregate_failures) do
  def unframed(source)
    within("lib/app/base.rb" => source) do
      project = Hashira::Project.new(["lib/app"])
      graph = outcome(Hashira::Pipeline.build(project)).graph
      trees = graph.code.to_h
      roots = Hashira::Coupling::Autoload.new(project, trees).roots
      framed(Hashira::Coupling::Surface.new(project.paths, trees, graph.lookup, roots), trees, graph.lookup)
    end
  end

  def framed(surface, trees, lookup)
    marks = Hashira::Coupling::Mentions.new(trees).marks(lookup, surface.openings)
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
