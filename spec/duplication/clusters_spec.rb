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
      "f.rb" => "def b(s)\n s.setup(fetch(:h))\n s.run(fetch(:p))\n s.warn(:x)\n s.close(:done)\nend\n"
    }
    expect(clusters(small)).to(be_empty)
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
end
