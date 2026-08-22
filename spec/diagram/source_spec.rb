# frozen_string_literal: true

RSpec.describe(Hashira::Diagram::Source) do
  it "renders dot with weighted labeled edges, declaring every package first" do
    with_pipeline do |_project, graph, _findings|
      output = capture { described_class.new(graph, :dot).print }
      expect(output).to(eq(<<~DOT))
        digraph hashira {
          rankdir=LR;
          "alpha";
          "beta";
          "core";
          "alpha" -> "beta" [label="1"];
          "alpha" -> "core" [label="1"];
          "beta" -> "alpha" [label="2"];
        }
      DOT
    end
  end

  it "renders mermaid with generated identifiers, declaring every package first" do
    with_pipeline do |_project, graph, _findings|
      output = capture { described_class.new(graph, :mermaid).print }
      expect(output).to(eq(<<~MERMAID))
        graph LR
          p0["alpha"]
          p1["beta"]
          p2["core"]
          p0 -->|1| p1
          p0 -->|1| p2
          p1 -->|2| p0
      MERMAID
    end
  end

  it "keeps a package that has no edges at all, which the picture used to lose" do
    files = {
      "lib/app/alpha/one.rb" => "module App; module Alpha; class One; def a = Beta::Two; end; end; end\n",
      "lib/app/beta/two.rb" => "module App; module Beta; class Two; def b = 1; end; end; end\n",
      "lib/app/lonely/x.rb" => "module App; module Lonely; class X; def c = 1; end; end; end\n"
    }
    analyze(files) do |_project, _census, graph|
      expect(capture { described_class.new(graph, :dot).print }).to(include(%(  "lonely";)))
      expect(capture { described_class.new(graph, :mermaid).print }).to(include(%(["lonely"])))
    end
  end

  it "escapes a quote or a backslash in a package name rather than breaking the graph" do
    edges = [['say "hi"', "back\\slash", 2]]
    source = Hashira::Diagram::Dot.new(edges, ['say "hi"', "back\\slash"]).source
    expect(source).to(include(%(  "say \\"hi\\"";), %(  "back\\\\slash";)))
    expect(source).to(include(%(  "say \\"hi\\"" -> "back\\\\slash" [label="2"];)))
  end

  it "never collides two packages onto one node, whatever they are called" do
    files = {
      "lib/app/my-pkg/a.rb" => "module App; class A; def a = 1; end; end\n",
      "lib/app/my_pkg/b.rb" => "module App; class B; def b = 1; end; end\n",
      "lib/app/end/c.rb" => "module App; class C; def c = 1; end; end\n"
    }
    analyze(files) do |_project, _census, graph|
      ids = capture { described_class.new(graph, :mermaid).print }.scan(/^  (p\d+)\[/)
      expect(ids.flatten).to(eq(ids.flatten.uniq))
      expect(ids.size).to(eq(graph.packages.size))
    end
  end
end
