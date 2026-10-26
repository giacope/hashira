# frozen_string_literal: true

RSpec.describe(Hashira::Smells::MiddleMan, :aggregate_failures) do
  let(:names) { %w[read write drop] }

  def relayed(source, rules = Hashira::Config::Rules::ALL)
    within("lib/app/cache.rb" => source) do
      project = Hashira::Project.new(["lib/app"])
      trees = project.files.to_h { [it, Prism.parse_file(it).value] }
      return Hashira::Smells::Report.new(project, trees, Hashira::Boundaries.new([], trees), rules).findings.select { it.kind == "middle_man" }
    end
  end

  def cache(extra = "", head = "class Cache") = <<~RUBY
    #{head}
      def initialize(store) = @store = store

      def read(key) = @store.read(key)
      def write(key, value) = @store.write(key, value)
      def expire(key, *rest, **options, &block) = @store.drop(key, *rest, **options, &block)
      def stats = Stats.new(@store)
      #{extra}
    end
  RUBY

  it "flags a class whose public methods mostly only forward to one field, naming them" do
    finding = relayed(cache).first
    expect([finding.package, finding.detail.to_h, finding.evidence]).to(
      eq(
        [
          "Cache", { site: "cache.rb:1", delegate: "@store", count: 3, total: 4 },
          ["read (line 4)", "write (line 5)", "expire (line 6)"]
        ]
      )
    )
  end

  it "says what it forwards to and what to do" do
    said = "Cache forwards 3 of its 4 public methods to @store (cache.rb:1). " \
      "Let callers talk to the delegate directly, or give the class work of its own."
    expect(message(relayed(cache).first)).to(eq(said))
  end

  it "counts forwarding through a reader of the field, under another name, and with anonymous or forwarded arguments" do
    readers = [
      "attr_reader :store\n  def fetch(key) = store.fetch_value(key)",
      "def touch(*, **) = @store.touch(*, **)"
    ]
    readers += ["def clear(...) = @store.clear_all(...)", "def scan(key, &) = @store.scan(key, &)"]
    expect(readers.map { relayed(cache(it)).first.detail.count }).to(eq([4, 4, 4, 4]))
  end

  it "leaves alone a class where forwarders are not most of its public methods" do
    expect(relayed(cache("def size = 1\n  def hits = 2"))).to(be_empty)
  end

  it "needs three forwarders to one delegate, a threshold a setting moves" do
    small = cache.sub("  def expire(key, *rest, **options, &block) = @store.drop(key, *rest, **options, &block)\n", "")
    rules = Hashira::Config::Rules.parse({ "middle_man" => { "threshold" => 2 } }, ["middle_man"])
    expect([relayed(small).size, relayed(small, rules).size]).to(eq([0, 1]))
  end

  it "does not count a call that changes, drops or reorders arguments, or does more than forward" do
    changed = [
      "def read(key) = @store.read(key.to_s)", "def write(key, value) = @store.write(value, key)",
      "def write(key, value) = @store.write(key)", "def read(key) = @store.read(key) { 1 }.to_s",
      "def read(key) = @store.read(key, ttl: 1)", "def read(key) = @store.read(key, &:to_s)",
      "def read(key, &block) = @store.read(key)", "def read(key, &) = @store.read(key) { 1 }"
    ]
    expect(changed.map { relayed(cache.sub(/  def #{it[/def (\w+)/, 1]}\(.*\n/, "  #{it}\n")) }).to(all(be_empty))
  end

  it "does not count a call given a block of its own, which does the method's work rather than forwarding" do
    source = <<~RUBY
      class Tally
        def initialize = (@mutex = Mutex.new; @count = 0; @items = [])
        def add = @mutex.synchronize { @count += 1 }
        def count = @mutex.synchronize { @count }
        def items = @mutex.synchronize { @items.dup }
      end
    RUBY
    expect(relayed(source)).to(be_empty)
  end

  it "does not count forwarding to a collection's own protocol, a local, a method call or a constant" do
    others = ["def size = @store.size", "def peek(key) = key.read(key)", "def sync(key) = build.read(key)"]
    others << "def load(key) = Store.read(key)"
    expect(others.map { relayed(cache.sub("  def read(key) = @store.read(key)\n", "  #{it}\n")) }).to(all(be_empty))
  end

  it "keyword arguments passed under their own name still forward" do
    source = cache.sub(
      "def write(key, value) = @store.write(key, value)",
      "def write(key:, value:) = @store.write(key:, value: value)"
    )
    expect(relayed(source).size).to(eq(1))
  end

  it "names the delegate most methods forward to, wherever it comes in the class" do
    source = cache.sub("  def read(key)", "  def log(line) = @log.write(line)\n  def read(key)")
    expect(relayed(source).first.detail.delegate).to(eq("@store"))
  end

  it "does not count calls on a constant, through a method that is not a reader, or through another's reader" do
    head = "class Cache\n  attr_reader :other\n  memoize :store\n  def store = Store.current\n"
    calls = %w[Store.%s(key) store.%s(key) @other.store.%s(key) other(1).%s(key)]
    sources = calls.map { |call| "#{head}#{names.map { "  def #{it}(key) = #{format(call, it)}\n" }.join}end\n" }
    expect(sources.map { relayed(it) }).to(all(be_empty))
  end

  it "leaves alone forwarders spread over several delegates" do
    facade = cache.sub("= @store.write(key, value)", "= @index.write(key, value)")
    expect(relayed(facade)).to(be_empty)
  end

  it "leaves alone a class that declares its delegation, or wraps a delegator, though others call its forwarders" do
    sources = ["extend Forwardable\n  def_delegators :@store, :keys", "delegate :keys, to: :store"].map { cache(it) }
    sources += ["class Cache < SimpleDelegator", "class Cache < ::DelegateClass(Store)"].map { cache("", it) }
    user = "\nclass User\n  def go(cache) = [cache.read(1), cache.write(1, 2), cache.expire(1)]\nend\n"
    based = relayed(cache("", "class Cache < Base") + user).size
    expect(sources.map { relayed(it + user) } + [based]).to(eq([[], [], [], [], 1]))
  end

  it "leaves private forwarders, a forwarder filling a role its kin share, and modules alone" do
    hidden = cache.sub("def read(key)", "private def read(key)")
    kin = "class Base\n  def read(key) = 1\n  def write(key, value) = 2\nend\n\n#{cache("", "class Cache < Base")}"
    expect([hidden, kin, cache("", "module Cache")].map { relayed(it) }).to(all(be_empty))
  end

  it "leaves alone a decorator: every public method it does not forward wraps the same call on the delegate" do
    decorated = ["def stats = \"hits: \#{@store.stats}\"", "def stats(key) = @store.stats(key).round"]
    expect(decorated.map { relayed(cache.sub("def stats = Stats.new(@store)", it)) }).to(all(be_empty))
  end

  it "still flags a class whose own work sends another message, the same message elsewhere, or adds a method" do
    others = ["def stats = @store.count.to_s", "def stats = @log.stats.to_s", "def stats = Stats.new(@store).stats"]
    sources = others.map { cache.sub("def stats = Stats.new(@store)", it) }
    sources << cache("def size = 1").sub("def stats = Stats.new(@store)", "def stats = @store.stats.to_s")
    expect(sources.map { relayed(it).size }).to(eq([1, 1, 1, 1]))
  end
end
