# frozen_string_literal: true

RSpec.describe(Hashira::Smells::BoundarySprawl, :aggregate_failures) do
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
