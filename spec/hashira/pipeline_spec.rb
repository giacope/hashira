# frozen_string_literal: true

RSpec.describe(Hashira::Pipeline, :aggregate_failures) do
  def run(enabled, boundaries: [])
    within(Fixtures::CYCLIC_FILES) do
      selection = Hashira::Selection.new(enabled)
      project = Hashira::Project.new(["lib/app"], boundaries:)
      yield(described_class.build(project, Hashira::Config::Rules.new({}), Fixtures::FLAT, selection))
    end
  end

  def kinds(enabled) = run(enabled) { return kept(it).map { it.to_h[:kind] }.uniq }

  def hotspots(enabled)
    verdicts = Hashira::Report::View::Verdicts.new([], Fixtures::CLEAR, Fixtures::JUDGED)
    run(enabled) { |pipeline| return JSON.parse(capture { outcome(pipeline).view(verdicts, Hashira::Report::View::Layout.new).json.print }) }
  end

  def told
    io = StringIO.new
    outcome(described_class.build(Hashira::Project.new(["lib/app"]))).notify(Hashira::Report::Warnings.new(io:))
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
    rolled = [%i[complexity], %i[duplication], %i[coupling smells]].map { hotspots(it).key?("hotspots") }
    expect(rolled).to(eq([true, true, false]))
  end
end
