# frozen_string_literal: true

RSpec.describe(Hashira::Suppression::Suppressions) do
  def screened(files, enabled: Hashira::Pipeline::ANALYZERS)
    within(files) { return Hashira::Pipeline.new(Hashira::Project.new(["lib/app"], rules: Hashira::Config::Rules::ALL), enabled:).verify.screened }
  end

  def nested(name)
    "def #{name}(a, b, c, d)\n  if a\n    if b\n      if c\n        d ? 1 : 2\n      end\n    end\n  end\nend\n"
  end

  def complex(head = "") = "class Knot\n#{head}#{nested("tangle")}end\n"

  it "silences the finding on the next line of code, keeping the reason" do
    source = complex("  # hashira:disable-next-line complexity, feature_envy -- a parser table\n\n  # generated\n")
    result = screened({ "lib/app/knot.rb" => source }, enabled: %i[complexity])
    expect(result.kept).to(be_empty)
    finding, directive = result.suppressed.first
    expect([finding.kind, directive.reason, directive.site, directive.kinds]).to(
      eq(["complexity", "a parser table", "knot.rb:2", %w[complexity feature_envy]])
    )
    expect(result.unused).to(be_empty)
  end

  it "silences the line a trailing directive sits on, and lists one that silences nothing as unused" do
    source = "class Knot\n#{nested("tangle").sub("d)\n", "d) # hashira:disable complexity -- table\n")}  " \
      "def calm = 1 # hashira:disable complexity -- stale\nend\n"
    result = screened({ "lib/app/knot.rb" => source }, enabled: %i[complexity])
    expect(result.suppressed.map { it.last.reason }).to(eq(["table"]))
    expect(result.unused.map(&:to_h)).to(
      eq(
      [
      {
        "site" => "knot.rb:11", "kinds" => ["complexity"],
        "reason" => "stale"
      }
    ]
    )
    )
  end

  it "keeps a finding of another kind on the same line" do
    source = complex("  # hashira:disable-next-line feature_envy -- not this one\n")
    expect(screened({ "lib/app/knot.rb" => source }, enabled: %i[complexity]).kept.map(&:kind)).to(eq(["complexity"]))
  end

  it "silences a smell on the line of the check it names" do
    source = "class Box\n  def initialize = @x = nil\n  def get\n    " \
      "@x.nil? # hashira:disable nil_check -- why\n  end\nend\n"
    result = screened({ "lib/app/box.rb" => source }, enabled: %i[smells])
    expect(result.suppressed.map { it.first.kind }).to(eq(["nil_check"]))
  end

  it "drops one copy from a clone and keeps the rest, until fewer than two remain" do
    body = "  def run(g)\n    g.configure(fetch(:host), fetch(:port))\n    g.connect(retries: 3, timeout: 30)\n    " \
      "g.authorize(token: load(:tok), scope: :sale)\n  end\n"
    copy = ->(name, head = "") { "class #{name}\n#{head}#{body}end\n" }
    silence = "  # hashira:disable-next-line duplication -- kept apart on purpose\n"
    files = {
      "lib/app/a.rb" => copy.call("A", silence), "lib/app/b.rb" => copy.call("B"),
      "lib/app/c.rb" => copy.call("C")
    }
    kept = screened(files, enabled: %i[duplication]).kept.first
    expect(
      [
        kept.package, kept.evidence.size, kept.detail.size,
        kept.anchors
    ]
    ).to(eq(["b.rb:2", 2, 2, ["b.rb:2", "c.rb:2"]]))
    result = screened(files.except("lib/app/c.rb"), enabled: %i[duplication])
    expect([result.kept, result.suppressed.size]).to(eq([[], 1]))
  end

  it "refuses a directive it cannot read, naming the file and line" do
    {
      "# hashira:disable-next-line complexity" => "knot.rb:2: hashira: directive needs a reason after --",
      "# hashira:disable-next-line envy -- typo" => 'names unknown kind "envy"',
      "# hashira:silence complexity -- why" => "silence is not a directive (use: disable, disable-next-line)",
      "# hashira:disable complexity -- why" => "disable sits on the line it silences",
      "# hashira:" => "reads hashira:VERB KIND[,KIND] -- REASON",
      "# hashira:disable-next-line  -- why" => "names no kind"
    }.each do |comment, message|
      files = { "lib/app/knot.rb" => "class Knot\n  #{comment}\n  def a = 1\nend\n" }
      expect { screened(files, enabled: %i[complexity]) }.to(raise_error(Hashira::Error, /#{Regexp.escape(message)}/))
    end
    files = { "lib/app/knot.rb" => "class Knot\nend\n# hashira:disable-next-line complexity -- end\n" }
    expect { screened(files, enabled: %i[complexity]) }.to(raise_error(Hashira::Error, /has no line of code after it/))
  end
end
