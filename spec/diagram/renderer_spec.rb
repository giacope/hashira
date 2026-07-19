# frozen_string_literal: true

RSpec.describe Hashira::Diagram::Renderer do
  it "renders dot with weighted labeled edges" do
    with_pipeline do |_project, graph, _findings|
      output = capture_stdout { described_class.new(graph, :dot).display }
      expect(output).to eq(<<~DOT)
        digraph hashira {
          rankdir=LR;
          "alpha" -> "beta" [label="1"];
          "alpha" -> "core" [label="1"];
          "beta" -> "alpha" [label="2"];
        }
      DOT
    end
  end

  it "renders mermaid with sanitized identifiers" do
    with_pipeline do |_project, graph, _findings|
      output = capture_stdout { described_class.new(graph, :mermaid).display }
      expect(output).to eq(<<~MERMAID)
        graph LR
          alpha["alpha"] -->|1| beta["beta"]
          alpha["alpha"] -->|1| core["core"]
          beta["beta"] -->|2| alpha["alpha"]
      MERMAID
    end
  end

  it "sanitizes non-word characters in mermaid identifiers" do
    files = {
      "lib/app/loose.rb" => "module App; class Loose; def c = Alpha::One; end; end\n",
      "lib/app/alpha/one.rb" => "module App; module Alpha; class One; def a = 1; end; end; end\n"
    }
    analyze(files) do |_project, _census, graph|
      output = capture_stdout do
        described_class.new(graph, :mermaid).display
      end
      expect(output).to include('_root_["(root)"] -->|1| alpha["alpha"]')
    end
  end
end
