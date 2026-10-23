# frozen_string_literal: true

RSpec.describe(Hashira::Pipeline, :aggregate_failures) do
  def run(enabled, boundaries: [])
    within(Fixtures::CYCLIC_FILES) do
      yield(described_class.new(Hashira::Project.new(["lib/app"], boundaries:), enabled:))
    end
  end

  def kinds(enabled) = run(enabled) { return it.findings.map(&:kind).uniq }

  def hotspots(enabled) = run(enabled) { return it.hotspots }

  def told
    io = StringIO.new
    described_class.new(Hashira::Project.new(["lib/app"])).notify(Hashira::Report::Notices.new(io:))
    io.string.lines.grep(/git history/)
  end

  def commit(note)
    File.write("lib/app/note.rb", "# #{note}\n")
    git("add", "-A")
    git("-c", "user.email=t@t", "-c", "user.name=t", "-c", "commit.gpgsign=false", "commit", "-qm", note)
  end

  def histories
    bare = told
    git("init", "-q")
    %w[one two].each { commit(it) }
    [bare, told]
  end

  it "says nothing about history once two commits weigh the churn" do
    expect(within(Fixtures::CYCLIC_FILES) { histories })
      .to(eq([["hashira: no git history for lib/app — hotspots are ranked by cost alone\n"], []]))
  end

  it "verifies declared boundaries even when no analyzer would consult them" do
    unused = { "root" => "Prism", "role" => "interpreted_model", "entrypoint" => "lib/app/x.rb", "reason" => "r" }
    run(%i[coupling], boundaries: [unused]) do |pipeline|
      expect { pipeline.verify }.to(raise_error(Hashira::Error, /boundary Prism has no root calls/))
    end
  end

  it "reports structural findings only when coupling runs" do
    expect([kinds(%i[coupling]), kinds(%i[complexity])]).to(eq([%w[cycle], []]))
  end

  it "rolls up hotspots when either cost analyzer runs, and not when neither does" do
    rolled = [%i[complexity], %i[duplication], %i[coupling smells]].map { hotspots(it).class }
    expect(rolled).to(eq([Hashira::Hotspots::Rollup, Hashira::Hotspots::Rollup, NilClass]))
  end
end
