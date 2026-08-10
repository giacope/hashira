# frozen_string_literal: true

RSpec.describe(Hashira::Smells::BoundarySprawl) do
  it "flags one foreign type picked apart across many methods and files" do
    findings = sniffed(spread(methods: 12, files: 3), "boundary_sprawl")
    finding = findings.first
    expect(findings.size).to(eq(1))
    expect(finding.package).to(eq("Prism"))
    expect(finding.detail).to(eq(count: 12, files: 3))
    expect(finding.evidence.size).to(eq(4))
    expect(finding.evidence.first).to(include("zone/probe0.rb:4"))
    expect(message(finding)).to(
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
  it "never counts a type the codebase defines" do
    files = spread(methods: 12, files: 3, tested: "Zone::Probe0")
    expect(sniffed(files, "boundary_sprawl")).to(be_empty)
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
