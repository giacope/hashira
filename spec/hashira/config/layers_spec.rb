# frozen_string_literal: true

RSpec.describe(Hashira::Config::Layers, :aggregate_failures) do
  def rank(raw, file, package) = described_class.parse(raw, "/srv").rank(file, package)

  it "reads layers outermost first, each a package name or a name with packages and paths" do
    raw = ["web", { "app" => "jobs" }, { "domain" => %w[models lib/billing] }]
    ranks = [%w[/srv/x.rb web], %w[/srv/x.rb jobs], %w[/srv/lib/billing/a.rb other], %w[/srv/lib/billing x]]
    expect([described_class.parse(raw).names] + ranks.map { rank(raw, *it) }).to(eq([%w[web app domain], 0, 1, 2, 2]))
  end

  it "reads a mapping in its order, and places a file outside every layer nowhere" do
    raw = { "web" => ["app/controllers"], "domain" => "app/models" }
    expect([rank(raw, "/srv/app/models/user.rb", "User"), rank(raw, "/srv/app/jobs/a.rb", "A")]).to(eq([1, nil]))
  end

  it "reads rails as the conventional web, app and domain folders, outermost first, other app folders as app" do
    files = %w[
      app/views/a.rb app/mailers/a.rb app/jobs/a.rb lib/a.rb app/forms/a.rb lib/mailers/previews/a.rb
      spec/mailers/b_preview.rb config/a.rb
    ].map { "/srv/#{it}" }
    expect([described_class.parse("rails").names, files.map { rank("rails", it, "A") }]).to(
      eq([%w[web app domain], [0, 0, 1, 2, 1, 0, 0, nil]])
    )
  end

  it "never proposes an order that puts the rails preset's app below its domain" do
    orders = [%w[web app domain], %w[web domain app]]
    found = ["rails", %w[web app domain]].map { |raw| orders.map { described_class.parse(raw).allows?(it) } }
    expect(found).to(eq([[true, false], [true, true]]))
  end

  it "stands for no layers when none are declared" do
    expect([described_class.parse(nil).any?, described_class::NONE.names]).to(eq([false, []]))
  end

  def refusal(raw)
    described_class.parse(raw)
  rescue Hashira::Error => error
    error.message.split(/ (?:to|of|more) /).first
  end

  it "refuses what it cannot order" do
    problems = [["web"], "web", [1, "app"], [{ "web" => [nil] }, "app"], [{ "a" => "x", "b" => "y" }, "c"], %w[web web]]
    said = (problems + [[{ "web" => "x" }, { "app" => "x" }]]).map { refusal(it) }.uniq
    expect(said).to(
      eq(
        [
          "layers needs at least two layers", "layers takes a list, outermost first,",
          'layers names "web"', 'layers names "x"'
        ]
      )
    )
  end

  it "keeps the rails preset's extra folders to the preset" do
    plain = described_class.new([described_class::Layer.new(name: "app", parts: [], home: "/srv")])
    expect(
      [
        rank(%w[web jobs domain], "/srv/lib/mailers/previews/a.rb", "A"),
        plain.allows?(%w[web domain app])
      ]
    ).to(eq([nil, true]))
  end
end
