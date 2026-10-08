# frozen_string_literal: true

RSpec.describe(Hashira::Duplication::Delta) do
  def kind(sources) = described_class.new(cluster(sources)).kind

  def clone(first, second)
    body = ->(recv) { "def run\n #{recv}\n #{recv}\n #{recv}\nend\n" }
    { "a.rb" => body.call(first), "b.rb" => body.call(second) }
  end
  it "reports :identical when the sites are byte-for-byte the same" do
    expect(kind(clone("g.emit(fetch(:h), fetch(:p))", "g.emit(fetch(:h), fetch(:p))"))).to(eq(:identical))
  end

  it "reports :literal when only literal values differ" do
    expect(kind(clone("emit(fetch(:h), 1)", "emit(fetch(:h), 9)"))).to(eq(:literal))
  end

  it "reports :message when only the receiver differs" do
    expect(kind(clone("x.emit(fetch(:h), fetch(:p))", "y.emit(fetch(:h), fetch(:p))"))).to(eq(:message))
  end

  it "reports :constant when only a constant reference differs" do
    expect(kind(clone("Foo.emit(fetch(:h), fetch(:p))", "Bar.emit(fetch(:h), fetch(:p))"))).to(eq(:constant))
  end

  it "reports :literal when only a string differs" do
    expect(kind(clone('emit(fetch(:h), "one")', 'emit(fetch(:h), "two")'))).to(eq(:literal))
  end

  it "reports :renamed, not :identical, when the same body sits under different method names" do
    sources = clone("g.emit(fetch(:h), fetch(:p))", "g.emit(fetch(:h), fetch(:p))")
    expect(kind(sources.merge("b.rb" => sources["b.rb"].sub("def run", "def call")))).to(eq(:renamed))
  end

  it "does not call methods that relay to super renamed, since each reaches a different parent method" do
    body = "\n x.compact!\n y = x.map(&:to_s).uniq\n y.select { it }.sort\n y.freeze\nend\n"
    relay = ->(name, call) { "def #{name}(*keys)\n x = #{call}#{body}" }
    bare = { "a.rb" => relay.call("slice", "super"), "b.rb" => relay.call("except", "super") }
    explicit = { "a.rb" => relay.call("slice", "super(*keys)"), "b.rb" => relay.call("except", "super(*keys)") }
    expect([kind(bare), kind(explicit)]).to(eq(%i[mixed mixed]))
  end

  it "keeps the different method names in view once something inside the renamed methods differs too" do
    literal = clone("emit(fetch(:h), 1)", "emit(fetch(:h), 9)")
    mixed = clone("x.emit(fetch(:h), 1)", "y.emit(fetch(:h), 9)")
    renamed = [literal, mixed].map { kind(it.merge("b.rb" => it["b.rb"].sub("def run", "def call"))) }
    expect(renamed).to(eq(%i[renamed_literal renamed_mixed]))
  end

  it "does not pass a callback's name off as a literal when two callbacks differ in a literal too" do
    line = ->(type) { "\n g.emit(fetch(:h), node.identifier.short_name, #{type})" }
    callback = ->(name, type) { "def #{name}(node)#{line[type] * 3}\nend\n" }
    sources = { "a.rb" => callback.call("on_class", ":class"), "b.rb" => callback.call("on_module", ":module") }
    expect(kind(sources)).to(eq(:renamed_literal))
  end

  it "reports :nil_guard when one copy guards a call with safe navigation and the other does not" do
    sources = clone("g.client.emit(fetch(:h), 1)", "g.client&.emit(fetch(:h), 1)")
    expect(kind(sources)).to(eq(:nil_guard))
    expect(kind(sources.merge("b.rb" => sources["b.rb"].sub("def run", "def call")))).to(eq(:renamed_nil_guard))
    expect(kind(clone("g.client.emit(fetch(:h), 1)", "g.client&.emit(fetch(:h), 2)"))).to(eq(:mixed))
  end

  it "reports :mixed when more than one kind of thing differs" do
    expect(kind(clone("x.emit(fetch(:h), 1)", "y.emit(fetch(:h), 9)"))).to(eq(:mixed))
  end

  it "reports :structure when the control flow differs across a near-miss" do
    near = {
      "c.rb" => "def a(r)\n r.configure(host: fetch(:h), port: fetch(:p))\n " \
        "r.connect(retries: 3, timeout: 30)\n r.authenticate(token: load(:t), scope: :admin)\nend\n",
      "d.rb" => "def b(s)\n s.configure(host: fetch(:h), port: fetch(:p))\n " \
        "s.connect(retries: 3, timeout: 30)\n s.warn(:slow)\n " \
        "s.authenticate(token: load(:t), scope: :admin)\nend\n"
    }
    expect(kind(near)).to(eq(:structure))
  end

  it "reports :structure over a literal drift, measured by the shape most sites share" do
    base =
      lambda do |timeout, extra = ""|
        "def run(gateway)\n gateway.configure(fetch(:host), fetch(:port))\n " \
          "gateway.connect(retries: 3, timeout: #{timeout})\n#{extra} " \
          "gateway.authorize(token: load(:tok), scope: :sale)\n " \
          "gateway.settle(amount: total(:net), currency: :eur)\nend\n"
      end
    sources = { "a.rb" => base[30], "b.rb" => base[60], "c.rb" => base[30, " gateway.log(:slow)\n"] }
    expect(cluster(sources)).to(have_attributes(size: 3, mass: 47))
    expect(kind(sources)).to(eq(:structure))
  end

  it "serializes to a hash whose kind selects the refactoring advice" do
    delta = described_class.new(cluster(clone("emit(fetch(:h), 1)", "emit(fetch(:h), 9)")))
    expect(delta.to_h).to(include(sites: 2, kind: :literal))
    expect(Hashira::Report::Phrases::DUPLICATION_ADVICE.fetch(delta.kind)).to(include("extract a method"))
  end
end
