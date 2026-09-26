# frozen_string_literal: true

RSpec.describe(Hashira::Duplication::Clusters) do
  def clusters(sources) = described_class.new(fragments(sources)).sorted

  def exact
    {
      "a.rb" => "def a(g)\n g.configure(fetch(:h), fetch(:p))\n g.connect(3, 30)\n g.finalize(:x, :y)\nend\n",
      "b.rb" => "def b(g)\n g.configure(fetch(:h), fetch(:p))\n g.connect(3, 30)\n g.finalize(:x, :y)\nend\n"
    }
  end

  def near
    {
      "c.rb" => "def a(r)\n r.configure(host: fetch(:h), port: fetch(:p))\n r.connect(retries: 3, timeout: 30)\n " \
        "r.authenticate(token: load(:t), scope: :admin)\nend\n",
      "d.rb" => "def b(s)\n s.configure(host: fetch(:h), port: fetch(:p))\n s.connect(retries: 3, timeout: 30)\n " \
        "s.warn(:slow)\n s.authenticate(token: load(:t), scope: :admin)\nend\n"
    }
  end
  it "clusters an exact clone into one finding covering both sites, at maximal size" do
    clusters = clusters(exact)
    expect(clusters.size).to(eq(1))
    expect(clusters.first.size).to(eq(2))
    expect(clusters.first.mass).to(eq(23))
    expect(clusters.first.canonical.range).to(eq("a.rb:1-5"))
    expect(clusters.first.masses).to(eq([["a.rb", 23], ["b.rb", 23]]))
  end

  it "keeps an exact pair that a near-miss neighbour drags below the raised floor" do
    drifted = {
      "c.rb" => "def c(g)\n g.configure(fetch(:h), fetch(:p))\n g.connect(3, 30)\n g.warn(:slow)\n " \
        "g.finalize(:x, :y)\nend\n"
    }
    cluster = clusters(exact.merge(drifted)).first
    expect(cluster.sites.map(&:file)).to(contain_exactly("a.rb", "b.rb"))
    expect(cluster.mass).to(eq(23))
  end

  it "pulls a near-miss variant into the cluster as a distinct site" do
    cluster = clusters(near).first
    expect(cluster.size).to(eq(2))
    expect(cluster.sites.map(&:types).uniq.size).to(eq(2))
  end

  it "suppresses a near-miss below the raised near-miss floor" do
    small = {
      "e.rb" => "def a(r)\n r.setup(fetch(:h))\n r.run(fetch(:p))\n r.close(:done)\nend\n",
      "f.rb" => "def b(s)\n s.setup(fetch(:h))\n s.run(fetch(:p))\n s.warn\n s.close(:done)\nend\n"
    }
    expect(clusters(small)).to(be_empty)
  end

  it "finds an exact stretch even when one copy runs a statement longer" do
    body = " g.configure(fetch(:h), fetch(:p))\n g.connect(3, 30)\n g.finalize(:x, :y)\n"
    longer = { "a.rb" => "def a(g)\n#{body} g.log(:done)\nend\n", "b.rb" => "def b(g)\n#{body}end\n" }
    expect(clusters(longer).map { it.sites.map(&:range) }).to(eq([["a.rb:2-4", "b.rb:2-4"]]))
  end

  it "reports an exact clone whose mass sits exactly on the floor" do
    source = "r.setup(fetch(:h))\nr.run(fetch(:p))\nr.close(:done)\n"
    expect(clusters("a.rb" => source, "b.rb" => source).map(&:mass)).to(eq([16]))
  end

  it "pairs a near-miss right at the mass ratio limit" do
    head = "r.configure(host: fetch(:h), port: fetch(:p)).connect(:tcp, :tls, retries: 3, timeout: 30)" \
      ".authenticate(token: load(:t), scope: :admin)"
    tail = ".audit(user: current(:id), at: now(:utc), level: 1).notify(:ops, :team)"
    cluster = clusters("c.rb" => "def a(r) = #{head}\n", "d.rb" => "def b(r) = #{head}#{tail}\n").first
    expect(cluster.sites.map(&:mass)).to(contain_exactly(40, 60))
  end

  it "keeps two unrelated clones apart when they sit side by side in one method" do
    pay = " gateway.configure(fetch(:host), fetch(:port))\n gateway.connect(retries: 3, timeout: 30)\n " \
      "gateway.authorize(token: load(:tok), scope: :sale)\n"
    ship = " @carrier = Carrier.lookup(order.region)\n label = @carrier.print(order.address, format: :pdf)\n " \
      "queue << [label, order.id] unless label.nil?\n"
    sources = {
      "a.rb" => "def a(gateway, order, queue)\n#{pay}#{ship}end\n",
      "b.rb" => "def b(gateway)\n#{pay}end\n", "c.rb" => "def c(order, queue)\n#{ship}end\n"
    }
    expect(clusters(sources).map { it.sites.map(&:range) }).to(eq([["a.rb:2-4", "b.rb:2-4"], ["a.rb:5-7", "c.rb:2-4"]]))
  end

  it "reports a repeat inside one method once, never as one site or as sites sharing a statement" do
    one = " g.configure(host: fetch(:h), port: fetch(:p), mode: :sync)\n"
    two = " g.authorize(token: load(:t), scope: :admin)\n"
    repeated = { "a.rb" => "def m(g)\n#{one}#{two}#{one}#{two}#{one}end\n" }
    expect(clusters(repeated).map { it.sites.map(&:range) }).to(eq([["a.rb:2-3", "a.rb:4-5"]]))
  end

  it "does not pair a small method with a much larger one that merely contains it" do
    loop = " while x.next?\n  x.step(1)\n end\n"
    rest = " x.report(total: x.sum(:net), tax: x.sum(:vat))\n " \
      "x.archive(path: File.join(root, name), mode: :append)\n x.notify(users.map(&:email), subject: :done)\n"
    expect(clusters("a.rb" => "def a(x)\n#{loop}end\n", "b.rb" => "def b(x)\n#{loop}#{rest}end\n")).to(be_empty)
  end

  it "does not pair methods of a size that only share a rare construct" do
    one = "def a(list)\n until list.empty?\n  item = list.shift\n  process(item, mode: :fast) if item.ready?\n end\n " \
      "log.info(\"done: \#{list.size}\")\n @seen = Set.new([1, 2, 3])\n " \
      "report(@seen.to_a, header: [:id, :name])\nend\n"
    two = "def b(table)\n rows = table.fetch(:rows, [])\n until rows.none?\n  emit(rows.pop.to_s.strip, :csv)\n " \
      "end\n case rows.first\n when Hash then rows.map { |r| r.transform_keys(&:to_s) }\n " \
      "else rows.flatten.compact.uniq\n end\nend\n"
    expect(clusters("a.rb" => one, "b.rb" => two)).to(be_empty)
  end

  it "clusters a lone expression big enough to stand on its own" do
    body =
      lambda do |icon, label|
        %(image_tag("#{icon}", aria: { hidden: "true" }, size: 20) + tag.span("#{label}", class: "sr"))
      end
    helper = {
      "a.rb" => "def back\n link_to dest, class: \"btn\" do\n  #{body["back.svg", "Go Back"]}\n end\nend\n",
      "b.rb" => "def save\n tag.button type: \"submit\" do\n  #{body["save.svg", "Save"]}\n end\nend\n"
    }
    expect(clusters(helper).first.sites.map(&:range)).to(contain_exactly("a.rb:3-3", "b.rb:3-3"))
  end

  it "holds a match that shares nothing but its shape to the near-miss floor" do
    coincidence = {
      "i.rb" => "def a(path)\n path.each_cons(2).min_by { |from, to| weight(from, to) }\nend\n",
      "j.rb" => "def b(pool)\n pool.combination(2).select { |left, right| near?(left, right) }\nend\n"
    }
    expect(clusters(coincidence)).to(be_empty)
  end

  it "ignores trivial fragments below the mass floor" do
    tiny = { "g.rb" => "def a\n x\n y\nend\n", "h.rb" => "def b\n x\n y\nend\n" }
    expect(clusters(tiny)).to(be_empty)
  end

  it "does not report a single method's own overlapping windows as duplication" do
    solo = {
      "s.rb" => "def m(g)\n g.a(fetch(:x), fetch(:y))\n g.b(fetch(:x), fetch(:y))\n " \
        "g.c(fetch(:x), fetch(:y))\nend\n"
    }
    expect(clusters(solo)).to(be_empty)
  end

  it "leaves a run of declarative macros alone — the shared shape is the schema" do
    schema = {
      "order.rb" => "class Order < ApplicationRecord\n has_many :line_items, dependent: :destroy\n " \
        "has_many :adjustments, dependent: :destroy\n belongs_to :customer\n " \
        "validates :reference, presence: true\nend\n",
      "invoice.rb" => "class Invoice < ApplicationRecord\n has_many :payments, dependent: :destroy\n " \
        "has_many :credits, dependent: :destroy\n belongs_to :account\n " \
        "validates :number, presence: true\nend\n"
    }
    expect(clusters(schema)).to(be_empty)
  end

  it "still reads a macro body as code once it carries logic of its own" do
    logic = {
      "order.rb" => "class Order < ApplicationRecord\n belongs_to :customer\n " \
        "def total\n  lines.sum { it.price * it.count }\n end\nend\n",
      "invoice.rb" => "class Invoice < ApplicationRecord\n belongs_to :account\n " \
        "def total\n  lines.sum { it.price * it.count }\n end\nend\n"
    }
    expect(clusters(logic).first.sites.map(&:file)).to(contain_exactly("order.rb", "invoice.rb"))
  end

  it "keeps receiverless macros with runtime arguments as executable code" do
    runtime = {
      "a.rb" => <<~RUBY,
        class A
          add feature_enabled?(enabled?, enabled?)
          add feature_enabled?(enabled?, enabled?)
          add feature_enabled?(enabled?, enabled?)
        end
      RUBY
      "b.rb" => <<~RUBY
        class B
          add feature_enabled?(enabled?, enabled?)
          add feature_enabled?(enabled?, enabled?)
          add feature_enabled?(enabled?, enabled?)
        end
      RUBY
    }
    expect(clusters(runtime).first.sites.map(&:file)).to(contain_exactly("a.rb", "b.rb"))
  end

  it "reads macros sent to a receiver as code, not as a schema" do
    macros = ->(name) { "class #{name}\n Config.set :a, 1\n Config.put \"b\", 2.0\n Config.flag :c, true, nil\nend\n" }
    expect(clusters("a.rb" => macros["A"], "b.rb" => macros["B"]).first.sites.map(&:file)).to(eq(["a.rb", "b.rb"]))
  end

  it "leaves a run of bare macros alone — a directive with no arguments is still schema" do
    bare = {
      "a.rb" => <<~RUBY,
        class A
          audited
          versioned
          paranoid
          searchable
          sluggable
          taggable
          sortable
          cacheable
          auditable
          trackable
          archivable
          publishable
          countable
          rankable
        end
      RUBY
      "b.rb" => <<~RUBY
        class B
          audited
          versioned
          paranoid
          searchable
          sluggable
          taggable
          sortable
          cacheable
          auditable
          trackable
          archivable
          publishable
          countable
          rankable
        end
      RUBY
    }
    expect(clusters(bare)).to(be_empty)
  end

  describe(Hashira::Duplication::Index) do
    it "files each fragment under its rarest token types, so a shared rare type brings a pair together" do
      sources = { "a.rb" => "foo(1)\n", "b.rb" => "bar(2)\n", "c.rb" => "baz(:s)\n", "d.rb" => "qux(:t)\n" }
      buckets = described_class.new(fragments(sources)).buckets.map { it.map(&:file) }
      expect(buckets).to(include(%w[a.rb b.rb], %w[c.rb d.rb]))
    end
  end
end
