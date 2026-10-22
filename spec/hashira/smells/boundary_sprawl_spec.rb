# frozen_string_literal: true

RSpec.describe(Hashira::Smells::BoundarySprawl, :aggregate_failures) do
  # App::Ast copies Prism's node classes, App::Types copies App::Ast's, and
  # App::Node aliases Parser's node class.
  let(:copies) { <<~RUBY }
    module App
      module Ast
        %i[CallNode DefNode].each { |name| const_set(name, Prism.const_get(name)) }
      end
    end
  RUBY

  let(:relay) { <<~RUBY }
    module App
      module Types
        App::Ast.constants.each { |name| const_set(name, App::Ast.const_get(name)) }
      end
    end
  RUBY

  it "flags one foreign type picked apart across many methods and files" do
    findings = sniffed(spread(methods: 12, files: 3), "boundary_sprawl")
    expect(findings.map { [it.package, it.detail, it.evidence.size] }).to(eq([["Prism", { count: 12, files: 3 }, 4]]))
    expect(findings.first.evidence.first).to(include("zone/probe0.rb:4"))
    expect(message(findings.first)).to(
      include(
        "12 methods across 3 files each pick apart Prism's internals",
        "Front the boundary with one adapter"
      )
    )
  end

  it "stays quiet below the method floor or when the sprawl sits in too few files" do
    expect(sniffed(spread(methods: 11, files: 3), "boundary_sprawl")).to(be_empty)
    expect(sniffed(spread(methods: 12, files: 2), "boundary_sprawl")).to(be_empty)
  end

  it "counts a foreign root the codebase never defines, whether or not hashira has it loaded" do
    findings = sniffed(spread(methods: 12, files: 3, tested: "Rubydex::Graph"), "boundary_sprawl")
    expect(findings.map(&:package)).to(eq(["Rubydex"]))
  end

  it "never counts a class built into Ruby itself, which has no adapter to be missing" do
    expect(sniffed(spread(methods: 12, files: 3, tested: "Hash"), "boundary_sprawl")).to(be_empty)
    expect(sniffed(spread(methods: 12, files: 3, tested: "Process::Status"), "boundary_sprawl")).to(be_empty)
  end

  it "never counts a type the codebase defines" do
    files = spread(methods: 12, files: 3, tested: "Zone::Probe0")
    expect(sniffed(files, "boundary_sprawl")).to(be_empty)
  end

  it "counts a type tested through a namespace that copies a foreign one's constants against that foreign root" do
    files = spread(methods: 12, files: 3, tested: "App::Ast::CallNode").merge("lib/app/ast.rb" => copies)
    expect(sniffed(files, "boundary_sprawl").map(&:package)).to(eq(["Prism"]))
  end

  it "follows a copy of a copy, and an alias, to the foreign root" do
    relayed = spread(methods: 12, files: 3, tested: "App::Types::CallNode").merge("lib/app/ast.rb" => copies + relay)
    aliased = spread(methods: 12, files: 3, tested: "App::Node")
      .merge("lib/app/node.rb" => "module App\n  Node = Parser::AST::Node\nend\n")
    expect([relayed, aliased].map { sniffed(it, "boundary_sprawl").map(&:package) }).to(eq([["Prism"], ["Parser"]]))
  end

  it "takes no copy from a const_get of another name or none, another fetch, or another setter" do
    odd = <<~RUBY
      module App
        module Ast
          const_set(:CallNode, Prism.const_get(:DefNode))
          %i[DefNode].each { |name| const_set(name, Prism.const_get) }
          %i[CallNode].each { |name| const_set(name, Prism.fetch(name)) }
          %i[CallNode].each { |name| register(name, Prism.const_get(name)) }
        end
      end
    RUBY
    files = spread(methods: 12, files: 3, tested: "App::Ast::CallNode").merge("lib/app/ast.rb" => odd)
    expect(sniffed(files, "boundary_sprawl").map(&:package)).to(eq(["App"]))
  end

  it "leaves a copying namespace the constants it defines itself" do
    owned = "module App\n  module Ast\n    class View; end\n  end\nend\n"
    files = spread(methods: 12, files: 3, tested: "App::Ast::View")
      .merge("lib/app/ast.rb" => copies, "lib/app/view.rb" => owned)
    expect(sniffed(files, "boundary_sprawl")).to(be_empty)
  end

  it "stays quiet for a declared interpreted model" do
    files = spread(methods: 12, files: 3).merge(
      "lib/app/trees.rb" => "class Trees; def parse = Prism.parse('1').value; end\n"
    )
    expect(within(files) { interpreted }).to(be_empty)
  end

  # The sprawl findings left once Prism is declared an interpreted model.
  def interpreted
    project = Hashira::Project.new(["lib/app"])
    trees = Hashira::Trees.new(project).all
    record = {
      "root" => "Prism", "role" => "interpreted_model",
      "entrypoint" => "lib/app/trees.rb", "reason" => "the AST is the input model"
    }
    report = Hashira::Smells::Report.new(project, trees, Hashira::Boundaries.new([record], trees), Fixtures::NONE)
    report.findings.select { it.kind == "boundary_sprawl" }
  end

  def spread(methods:, files:, tested: "Prism::CallNode")
    methods.times.group_by { it % files }.to_h do |slot, group|
      ["lib/app/zone/probe#{slot}.rb", <<~RUBY]
        module App
          module Zone
            class Probe#{slot}
        #{group.map { |index| probe(index, tested) }.join("\n").gsub(/^/, "      ")}
            end
          end
        end
      RUBY
    end
  end

  def probe(index, tested)
    <<~RUBY
      def probe#{index}(node)
        node.is_a?(#{tested}) && node.name
      end
    RUBY
  end
end
