# frozen_string_literal: true

RSpec.describe(Hashira::Duplication::Clones, :aggregate_failures) do
  it "reports one finding per cluster, with each site as evidence and a refactoring" do
    findings = duplication(Fixtures::DUPLICATION_FILES, &:findings)
    expect(findings.map { [it.kind, message(it)] }).to(match([["duplication", include("2 similar fragments")]]))
    expect(findings.first.evidence).to(
      include(a_string_matching(%r{orders/checkout\.rb:4-8}), a_string_matching(%r{billing/refund\.rb:4-8}))
    )
  end

  # Two methods share a head and a tail; two others share the head and the tail's first line.
  def overlapping
    shared = " r.configure(host: fetch(:h), port: fetch(:p))\n r.connect(retries: 3, timeout: 30)\n"
    archived = " r.archive(path: File.join(root, name), mode: :append, level: 9)\n"
    tail = "#{archived} r.notify(users.map(&:email), subject: :done)\n"
    bodies = { "a" => tail, "b" => tail, "c" => "#{archived} q = other.thing(:z)\n w.call(q) if q.ready?\n" }
    bodies["d"] = "#{archived} x.each { it.flush(now: true) }\n"
    bodies.to_h { |name, body| ["lib/app/#{name}.rb", "def #{name}(r)\n#{shared}#{body}end\n"] }
  end

  def measured(clones)
    [clones.clusters.flat_map(&:sites).select { it.file.end_with?("a.rb") }.map(&:mass), clones.coverage]
  end

  it "measures a file's coverage in distinct nodes, so lines two clusters share are counted once" do
    masses, coverage = duplication(overlapping) { measured(it) }
    expect(masses).to(eq([56, 41]))
    expect(coverage.transform_keys { File.basename(it) }).to(include("a.rb" => 56, "c.rb" => 41))
  end

  it "finds no duplication in code that has none" do
    files = { "lib/app/solo/x.rb" => "module App\n module Solo\n class X\n def a = 1\n end\n end\n end\n" }
    duplication(files) { |clones| expect(clones.findings).to(be_empty) }
  end

  it "warns, via churn, when both sites of a clone change more often than the typical file" do
    duplication(Fixtures::DUPLICATION_FILES) do |clones|
      churn = Hashira::Churn.new("orders/checkout.rb" => 5, "billing/refund.rb" => 4, "quiet.rb" => 1, "still.rb" => 1)
      finding = Hashira::Duplication::DuplicationFinding.new(clones.clusters.first, churn).to_finding
      expect(message(finding)).to(include("Both sites change often"))
    end
  end

  def digest_of(files) = duplication(files) { |clones| clones.findings.first.digest }

  it "keys a clone by a digest that survives it moving down the file and changes when it changes" do
    original = digest_of(Fixtures::DUPLICATION_FILES)
    changed = Fixtures::DUPLICATION_FILES.transform_values { it.gsub("gateway.connect(", "gateway.reconnect(1, ") }
    expect(original).to(match(/\A\h{12}\z/))
    expect(digest_of(Fixtures::DUPLICATION_FILES.transform_values { "\n\n#{it}" })).to(eq(original))
    expect(digest_of(changed)).not_to(eq(original))
  end
end
