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
end
