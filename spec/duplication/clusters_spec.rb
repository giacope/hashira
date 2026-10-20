# frozen_string_literal: true

RSpec.describe(Hashira::Duplication::Clusters) do
  def clusters(sources) = Hashira::Duplication::Clusters.new(fragments(sources)).sorted

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
    expect(clusters.first.sites.map(&:file)).to(eq(["a.rb", "b.rb"]))
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

  it "measures each site of a near-miss cluster by its own copy" do
    cluster = clusters(near).first
    expect(cluster.sites.map { [it.file, it.mass] }.sort).to(eq([["c.rb", 40], ["d.rb", 44]]))
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
          drop feature_enabled?(enabled?)
          flag feature_enabled?(enabled?, enabled?, enabled?)
        end
      RUBY
      "b.rb" => <<~RUBY
        class B
          add feature_enabled?(enabled?, enabled?)
          drop feature_enabled?(enabled?)
          flag feature_enabled?(enabled?, enabled?, enabled?)
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

  def resource(name, owner)
    "class #{name}Resource\n attribute :id\n attribute :#{owner}_name do |r| r.#{owner}.name end\n " \
      "attribute(:created, &:created_at)\n attribute :email do |r| r.#{owner}.contact.email end\n " \
      "belongs_to :tenant, default: -> { Current.tenant }\n attribute :state do it.status end\nend\n"
  end

  it "leaves a class's macros alone when their blocks only read, or their lambdas make one call" do
    expect(clusters("a.rb" => resource("Order", "buyer"), "b.rb" => resource("Invoice", "payer"))).to(be_empty)
  end

  it "reads the same macros as code outside a class body, or once a block or lambda carries logic" do
    outside = ->(name) { resource(name, "owner").sub(/\Aclass \w+\n/, "").delete_suffix("end\n") }
    logic = ->(name) { resource(name, "owner").sub("contact.email", "email || r.no").sub("Current.tenant", "a if b") }
    sites = [outside, logic].map { clusters("a.rb" => it["Order"], "b.rb" => it["Invoice"]).first.size }
    expect(sites).to(eq([2, 2]))
  end

  def attributes(name, param, methods)
    one, two, three, four, five, six = methods.split
    "class #{name}\n attribute :id\n attribute :a do |#{param}| #{param}.#{one}.#{two} || #{param}.#{three}(:a) " \
      "end\n attribute :b do |#{param}| #{param}.#{four}.#{five} if #{param}.#{six} end\nend\n"
  end

  it "does not count a macro name the class repeats three times as a name two copies share" do
    mine = "strip presence fallback to_s upcase visible?"
    sources = {
      "a.rb" => attributes("A", "r", mine),
      "b.rb" => attributes("B", "x", "squish first default to_sym downcase shown?")
    }
    expect(clusters(sources)).to(be_empty)
    expect(clusters(sources.transform_values { it.sub(" attribute :id\n", "") }).first.size).to(eq(2))
    expect(clusters(sources.merge("b.rb" => attributes("B", "x", mine))).first.size).to(eq(2))
  end

  it "leaves a macro alone whose block holds only more declarations" do
    settings =
      lambda do |group, host, port|
        "group :#{group} do\n string :host do\n  description \"#{host}\"\n  default \"#{host}.local\"\n end\n " \
          "integer :port do\n  description \"port\"\n  default #{port}\n end\n " \
          "boolean :tls do\n  description \"tls\"\n  default false\n end\nend\n"
      end
    expect(clusters("a.rb" => settings[:smtp, "mx", 25], "b.rb" => settings[:imap, "mail", 143])).to(be_empty)
  end

  it "reads a macro block as code once it takes a parameter or holds logic" do
    settings =
      lambda do |group, body|
        "group :#{group} do |g|\n string :host do\n  description \"host\"\n  #{body}\n end\n " \
          "integer :port do\n  description \"port\"\n  default 25\n end\nend\n"
      end
    expect(clusters("a.rb" => settings[:smtp, "default 1"], "b.rb" => settings[:imap, "default 2"])).not_to(be_empty)
    logic = ->(group) { settings[group, "default { ENV.fetch(\"HOST\") }"].sub(" |g|", "") }
    expect(clusters("a.rb" => logic[:smtp], "b.rb" => logic[:imap])).not_to(be_empty)
  end

  it "leaves mixins, frozen constants and plain heredoc arguments alone — they declare, they do not compute" do
    header =
      lambda do |name, limit|
        "class #{name}\n include Comparable\n extend Forwardable\n MSG = \"Use #{name}.\".freeze\n " \
          "LIMIT = #{limit}\n KINDS = %i[a b].freeze\n " \
          "def_node_matcher :bad?, <<~PATTERN\n  (send nil? :#{name}\n    " \
          "(int #{limit}))\n PATTERN\nend\n"
      end
    expect(clusters("a.rb" => header["A", 1], "b.rb" => header["B", 2])).to(be_empty)
  end

  it "reads a frozen list of constants, or a literal's plain message, as a declaration" do
    declared =
      lambda do |name|
        "class #{name}\n include Comparable\n extend Forwardable\n NAME = \"Thing\".downcase\n " \
          "KINDS = [Prism::DefNode, Prism::RescueNode, Prism::WhenNode].freeze\n " \
          "MORE = [Prism::CallNode, Prism::ConstantReadNode].freeze\nend\n"
      end
    expect(clusters("a.rb" => declared["A"], "b.rb" => declared["B"])).to(be_empty)
  end

  it "reads a literal table that freezes its values in place as a declaration, and a passed block as code" do
    pairs = %w[year month day hour minute second].map { "#{it}: \"'#{it[0]}'\"" }.join(", ")
    table = ->(name, tail) { "module #{name}\n MAP = { #{pairs} }.freeze\n #{tail}\nend\n" }
    expect(clusters("a.rb" => table["A", "MAP.each_value(&:freeze)"], "b.rb" => table["B", "MAP.each_value(&:freeze)"]))
      .to(be_empty)
    %w[MAP.each_value(&:dup) MAP.each_value(&@cb) MAP.each(&) x.each(&:freeze)].each do |tail|
      expect(clusters("a.rb" => table["A", tail], "b.rb" => table["B", tail])).not_to(be_empty)
    end
  end

  it "takes two runs that share only their shape and their operators for two lists, not one clone" do
    pods = <<~RUBY
      def a(params)
        cmd = []
        cmd << "--no-clean" unless params[:clean]
        cmd << "--x" unless params[:x]
        cmd
      end
    RUBY
    keys = <<~RUBY
      def b(json)
        out = []
        out << "key_id" unless json.key?(:key_id)
        out << "key" unless json.key?(:key)
        out
      end
    RUBY
    expect(clusters("a.rb" => pods, "b.rb" => keys)).to(be_empty)
  end

  it "reads a heredoc that interpolates, or a constant built by a message, as code" do
    header =
      lambda do |name, value|
        "class #{name}\n include Comparable\n extend Forwardable\n MSG = #{value}\n " \
          "LIMIT = 10\n KINDS = %i[a b].freeze\n def_node_matcher :bad?, <<~PATTERN\n  (send nil? :\#{x}\n    " \
          "(int 1))\n PATTERN\nend\n"
      end
    expect(clusters("a.rb" => header["A", "1"], "b.rb" => header["B", "2"])).not_to(be_empty)
    %w[Set.new "Use".ljust(20)].each do |value|
      built = ->(name) { header[name, value].sub("\#{x}", "x") }
      expect(clusters("a.rb" => built["A"], "b.rb" => built["B"])).not_to(be_empty)
    end
  end

  def client(patch = "def patch(path, body, headers: {}) = request(:patch, path, body: body.to_json, headers:)")
    "class Client\n def post(path, body, headers: {}) = request(:post, path, body: body.to_json, headers:)\n " \
      "#{patch}\n def request(verb, path, body:, headers:) = run(verb, path, body, headers)\nend\n"
  end

  it "leaves alone calls to the project's own method that differ only in what they pass it" do
    renamed = "def patch(route, data, headers: {}) = request(:patch, route, body: data.to_json, headers:)"
    blocked = client.sub("headers:)\n", "headers:) { it.retry }\n").sub("headers:)\n", "headers:) { it.fail }\n")
    expect([client, client(renamed), blocked].map { clusters("c.rb" => it) }).to(all(be_empty))
  end

  it "leaves alone one-line methods that each hand a shared method a different block" do
    source = <<~RUBY
      class Boosting
        def edited_meanwhile(to:) = meanwhile("jz@example.com", "JZ") { edit_message(:third, to:) }
        def boosted_meanwhile(with:) = meanwhile("david@example.com", "David") { boost(:third, with:) }
        def meanwhile(email, name, &) = using(email, name, &)
      end
    RUBY
    expect(clusters("b.rb" => source)).to(be_empty)
  end

  it "leaves alone tests whose body is one call to the project's own assertion, as it does such methods" do
    test =
      lambda do |name, who, route|
        "  test \"#{name}\" do\n    assert_leaves(users(:#{who})) { delete #{route}(users(:#{who})) }\n  end\n"
      end
    helper = "module Leaving; def assert_leaves(user, &) = yield; end\n"
    files = {
      "leaving.rb" => helper,
      "a.rb" => "class BotsTest\n#{test["a bot leaves", "bender", "bot_url"]}end\n",
      "b.rb" => "class UsersTest\n#{test["a person leaves", "david", "user_url"]}end\n"
    }
    expect(clusters(files)).to(be_empty)
    stranger = files.merge("leaving.rb" => "module Leaving; end\n")
    expect(clusters(stranger).map(&:size)).to(eq([2]))
  end

  it "still reports calls to a method the project does not define, or copies that differ beyond the arguments" do
    external = client.sub(/ def request.*\n/, "")
    renamed = client("def patch(path, body, headers: {}) = request(:post, path, body: body.to_json, headers:)")
    longer = client.gsub(/= (request\(:\w+, path)(.*)\n/, "\n  \\1\\2\n  log(:sent, path)\n end\n")
    expect([external, renamed, longer].map { clusters("c.rb" => it).first.size }).to(eq([2, 2, 2]))
  end

  it "still reports the copies inside the block a shared method is handed" do
    job =
      lambda do |name, id|
        "def #{name}\n transaction do\n  order = load(:order, #{id})\n  order.check(:stock, limit: 5, warn: true)\n  " \
          "order.save(:order, status: \"ok\", at: clock.now)\n end\nend\n"
      end
    source = "class Jobs\n#{job["pay", 1]}#{job["ship", 2]}def transaction = yield\nend\n"
    expect(clusters("j.rb" => source).map { it.canonical.statements.size }).to(eq([3]))
  end

  def toggles(one, two)
    body = "(by) = update!(state: :on, changed_by: by, changed_at: Time.current, note: \"\")"
    clusters("m.rb" => "class Member\n def #{one}#{body}\n def #{two}#{body.sub(":on", ":off")}\nend\n")
  end

  it "leaves alone a method and its inverse, which share their shape by design" do
    inverses = [
      %w[lock! unlock!], %w[activate deactivate], %w[enable_feature disable_feature],
      %w[mark_as_read mark_as_unread]
    ]
    expect(inverses.map { toggles(*it) }).to(all(be_empty))
    expect([%w[disconnect connect], %w[open close?]].map { toggles(*it) }).to(all(be_empty))
  end

  it "still reports two methods whose names are not each other's inverse" do
    pairs = [%w[lock! freeze!], %w[lock_account unlock_user], %w[lock unlock_now], %w[relock unlock]]
    expect(pairs.map { toggles(*it).size }).to(eq([1, 1, 1, 1]))
  end

  it "leaves alone a stretch two inverse methods share, and reports it outside them" do
    body = ->(word) { " update!(at: now, why:)\n audit(:#{word}, why:, at: clock.now)\n notify(:#{word}, why)\n" }
    inverse = "class A\n def lock!(why)\n#{body["lock"]} end\n def unlock!(why)\n#{body["unlock"]} end\nend\n"
    expect(clusters("a.rb" => inverse)).to(be_empty)
    expect(clusters("a.rb" => inverse.sub("def unlock!", "def freeze!")).first.size).to(eq(2))
    expect(clusters("a.rb" => inverse, "b.rb" => "def c(why)\n#{body["lock"]}end\n").first.size).to(eq(3))
  end

  def guard = "before_action { authorize!(:read, model.constantize, scope: current_tenant.id, via: :role) }"

  def authorized(count, line = guard)
    shown = ->(n) { "class C#{n}\n #{line}\n def show#{n}\n  render_thing(:k#{n})\n end\nend\n" }
    (1..count).to_h { ["c#{it}.rb", shown[it]] }
      .merge("c1.rb" => "class C1\n #{line}\n before_action :a, if: -> { params[:x].present?(1) }\nend\n")
      .merge("c2.rb" => "class C2\n #{line}\n before_action :b, if: -> { params[:y].present?(2) }\nend\n")
  end

  def twins
    body = " def index\n  records = scope.where(owner: current_user).order(created_at: :desc)\n  " \
      "render json: records.map { |r| serialize(r, detail: :full) }, status: :ok\n end\nend\n"
    { "t1.rb" => "class T1\n#{body}", "t2.rb" => "class T2\n#{body}" }
  end

  def kinds(sources) = clusters(sources).map { [Hashira::Duplication::Delta.new(it).kind, it.size] }

  it "reports a line ten files repeat as one convention listing every site, not as pairs that hold it" do
    sources = authorized(8).merge(twins.transform_values { it.sub("\n", "\n #{guard}\n") })
    expect(kinds(sources)).to(eq([[:identical, 2], [:convention, 10]]))
  end

  it "holds a repeated line under ten sites, or one whose sites share nothing but its shape, to the recurrence floor" do
    expect(clusters(authorized(9)).map(&:size)).to(eq([2]))
    unlike = ->(n) { "class U#{n}\n b#{n} { a#{n}!(:read, m#{n}.k#{n}, s: t#{n}.i#{n}, v: :r) }\nend\n" }
    expect(clusters((1..12).to_h { ["u#{it}.rb", unlike[it]] })).to(be_empty)
  end

  it "keeps a bigger clone that holds the convention line, once it outweighs the line by the base floor" do
    weighed = ->(tail) { clusters(authorized(10).transform_values { it.sub(/render_thing\(:k\d+/, "\\0#{tail}") }) }
    expect(weighed[", d, a: 1, b: 2, c: 3"].map { [it.size, it.mass] }).to(eq([[8, 32], [10, 16]]))
    expect(weighed[", a: 1, b: 2, c: 3"].map { [it.size, it.mass] }).to(eq([[10, 16]]))
  end

  it "drops a smaller clone kept alive by a single site the bigger clone does not cover" do
    expect(nested(1).map { it.sites.map(&:file) }).to(eq([%w[a.rb b.rb]]))
  end

  it "keeps a smaller clone that two sites outside the bigger clone share" do
    expect(nested(2).map { it.sites.map(&:file).sort }).to(eq([%w[a.rb b.rb], %w[c0.rb c1.rb]]))
  end

  it "keeps a clone whose site only shares a line with a bigger clone, rather than sitting inside it" do
    one, two, three, four, five = [
      "r.configure(host: fetch(:h), port: fetch(:p))", "r.connect(retries: 3, timeout: 30)",
      "r.authorize(token: load(:t), scope: :admin)", "r.archive(path: join(root, name), mode: :append)",
      "r.notify(users.map(&:email), subject: :done)"
    ].map { " #{it}\n" }
    sources = {
      "a.rb" => "def a(r)\n#{one}#{two}#{three}#{four}#{five}end\n",
      "b.rb" => "def b(r)\n#{one}#{two}#{three} r.x\nend\n",
      "c.rb" => "def c(r)\n#{three}#{four}#{five} r.y\nend\n"
    }
    expect(clusters(sources).map { it.sites.map(&:range) }).to(eq([%w[a.rb:2-4 b.rb:2-4], %w[a.rb:4-6 c.rb:2-4]]))
  end

  def nested(extra) = clusters(wholes.merge((0...extra).to_h { ["c#{it}.rb", "def c(r)\n#{head} r.x(#{it})\nend\n"] }))

  def wholes
    tail = " r.archive(path: File.join(root, name), mode: :append, level: 9)\n " \
      "r.notify(users.map(&:email), subject: :done)\n"
    %w[a b].to_h { ["#{it}.rb", "def #{it}(r)\n#{head}#{tail}end\n"] }
  end

  def head = " r.configure(host: fetch(:h), port: fetch(:p))\n r.connect(retries: 3, timeout: 30)\n"

  describe(Hashira::Duplication::Grouping) do
    it "breaks a tie between overlapping fragments in favour of the one another site shares names with" do
      body = ->(first, last) { "def m\n #{first}.go(1)\n mid.run\n #{last}.go(2)\nend\n" }
      all = fragments("a.rb" => body["alpha", "beta"], "b.rb" => body["gamma", "beta"])
      group = %w[a.rb:2-3 a.rb:3-4 b.rb:3-4].map { |range| all.find { it.range == range } }
      sites = [group, group.reverse].map { described_class.new(it).cluster.sites.map(&:range).sort }
      expect(sites).to(eq([%w[a.rb:3-4 b.rb:3-4]] * 2))
    end
  end

  it "weighs a constructor that only stores its arguments as nothing, and one that computes as code" do
    stored = ->(name, body) { "class #{name}\n KINDS = [Prism::DefNode, Prism::RescueNode].freeze\n#{body}end\n" }
    stores = %w[file tree root mode].map { "  @#{it} = #{it}\n" }.join
    plain = " def initialize(file, tree, root, mode)\n#{stores} end\n"
    computed = " def initialize(file, tree)\n  @file = file.to_s\n  @tree = tree.freeze\n end\n"
    sources = [plain, computed].map { |body| { "a.rb" => stored["A", body], "b.rb" => stored["B", body] } }
    expect(sources.map { clusters(it).size }).to(eq([0, 1]))
  end

  describe(Hashira::Duplication::Index) do
    it "files each fragment under its rarest token types, so a shared rare type brings a pair together" do
      sources = { "a.rb" => "foo(1)\n", "b.rb" => "bar(2)\n", "c.rb" => "baz(:s)\n", "d.rb" => "qux(:t)\n" }
      buckets = described_class.new(fragments(sources)).buckets.map { it.map(&:file) }
      expect(buckets).to(include(%w[a.rb b.rb], %w[c.rb d.rb]))
    end

    def disjoint(count) = (1..count).to_h { ["m#{it}.rb", "def m#{it}(x)\n#{calls(it, 1..9)}end\n"] }

    def calls(owner, numbers) = numbers.map { " x.c#{owner}_#{it}(1)\n" }.join

    def indexed(sources) = described_class.new(fragments(sources).select(&:opened?).uniq(&:range)).buckets

    it "keeps a bucket of sixty whole, and pairs crowded fragments that share most of their names, never none" do
      alike = "def m2(x)\n x.c2_0(1)\n#{calls(1, 2..9)}end\n"
      expect(indexed(disjoint(60)).map(&:size)).to(include(60))
      expect(indexed(disjoint(61).merge("m2.rb" => alike)).map { it.map(&:file) }.uniq).to(eq([%w[m1.rb m2.rb]]))
    end

    it "gives a fragment that names nothing no bands" do
      expect(fragments("a.rb" => "def a(x) = [x]\n").first.bands).to(eq([]))
    end
  end

  describe(Hashira::Duplication::Macro) do
    def pardons?(source) = described_class.new(Prism.parse(source).value.statements.body.first).pardoned.any?

    it "pardons a block that passes a symbol, or reads a chain of up to three plain calls off its parameter" do
      readers = ["a(&:id)", "a { |r| r.b.c.d }", "a { it.b }", "a { _1.b }", "a { b.c }", "a { |r| r&.b }"]
      expect(readers.map { pardons?(it) }.uniq).to(eq([true]))
    end

    it "keeps a block that computes: a longer chain, an argument, a block, a constant, a branch, a second statement" do
      computed = [
        "a(&b)", "a { |r| r.b.c.d.e }", "a { |r| r.b(1) }", "a { |r| r.b { 1 } }", "a { B.c }",
        "a { |r| r.b ? 1 : 2 }", "a { |r| r.b\n r.c }", "a { }", "a"
      ]
      expect(computed.map { pardons?(it) }.uniq).to(eq([false]))
    end

    it "pardons a keyword lambda whose body is one call or an ||, and nothing else" do
      pardoned = ["a :b, c: -> { D.e }", "a :b, c: -> { d || e }", "a(c: ->(x) { x.y(1) })"]
      kept = [
        "a :b, -> { d }", "a :b, c: -> { d if e }", "a :b, c: -> { d\n e }", "a :b, c: -> {}", "a :b, c: d",
        "a :b, **c"
      ]
      expect([pardoned, kept].map { |group| group.map { pardons?(it) }.uniq }).to(eq([[true], [false]]))
    end
  end

  describe(Hashira::Duplication::Sink) do
    def call(source) = Prism.parse(source).value.statements.body.first

    def sink?(source, rescued = nil) = described_class.new(parsed(source).statements.body.first, rescued).sink?

    def parsed(source) = Prism.parse(source, scopes: [[:e]]).value

    def pair(source)
      { "a.rb" => public_send(source, "charge", "Charge"), "b.rb" => public_send(source, "refund", "Refund") }
    end

    def logged(name, what)
      "class Checkout\n def #{name}_failed(error)\n  logger.error(\"#{what} failed for order \#{order.id} " \
        "(\#{order.customer.email}): \#{error.message} at \#{error.backtrace.first}\")\n end\nend\n"
    end

    def reported(name, _)
      "class Sync\n def #{name}(e)\n  error_reporter.report(e, context: { order_id: order.id, " \
        "customer_id: order.customer_id, amount: order.total, at: Time.current })\n end\nend\n"
    end

    def rescued(name, what)
      "def #{name}\n run\nrescue Timeout::Error => e\n Rails.logger.warn(\"#{what} timed out after " \
        "\#{e.elapsed.round(2)} seconds on \#{host.name}:\#{host.port}\")\nend\n"
    end

    def alerted(_, what)
      "if order.failed?(attempts: config.fetch(:attempts), since: Time.current - config.fetch(:window))\n " \
        "logger.error(\"#{what} failed for order \#{order.id}\")\nend\n"
    end

    def retried(name, _)
      "class Sync\n def #{name}(order)\n  logger.warn(\"retrying \#{order.id}\")\n  " \
        "order.retry_payment(attempts: fetch(:attempts), backoff: :exponential)\n  " \
        "notify(order.customer, :failed)\n end\nend\n"
    end

    def handed(name, what)
      "def #{name}\n run(:#{what})\nrescue Timeout::Error => e\n tracker.track(e, context: { order_id: order.id, " \
        "customer_id: order.customer_id, amount: order.total, at: Time.current })\nend\n"
    end

    it "skips a method or rescue clause whose one statement is a log line or hands on the rescued error" do
      expect(%i[logged rescued handed].map { clusters(pair(it)) }).to(all(be_empty))
    end

    it "counts a lone report that builds its own context outside a rescue: that context is the copy" do
      expect(clusters(pair(:reported)).size).to(eq(1))
    end

    it "still reports a log line among other statements, counting its interpolated message as one string" do
      cluster = clusters(pair(:retried)).first
      expect(cluster.sites.map(&:range)).to(eq(%w[a.rb:2-6 b.rb:2-6]))
      expect(cluster.mass).to(eq(25))
    end

    it "still reports a lone call that is not a sink, or a sink under a condition of its own" do
      plain = pair(:logged).transform_values { it.sub("logger.error", "ledger.record") }
      guarded = pair(:alerted)
      expect([plain, guarded].map { clusters(it).size }).to(eq([1, 1]))
    end

    it "knows a log line by Logger's severities on a logger, and a report by the rescued error it hands on" do
      logs = %w[logger.error(x) Rails.logger.info(x) @log.debug(x) app_logger.warn(x) self.logger.fatal(x) log.unknown]
      others = %w[logger.flush(x) order.error(x) error(x) ledger.info(x) x Sentry.capture_exception(e)]
      reports = %w[Sentry.capture_exception(e) Rails.error.report(e) notify(1,e)]
      unreported = %w[report(@e) report]
      plain = [logs, others].map { |group| group.map { sink?(it) } }
      judged = plain + [reports, unreported].map { |group| group.map { sink?(it, :e) } }
      expect(judged.map(&:uniq)).to(eq([[true], [false], [true], [false]]))
    end

    it "discounts every node a sink's interpolated messages hold, nested ones counted once" do
      fragment = fragments("a.rb" => "logger.info(\"a \#{\"b \#{c.d}\"}\", e)\nf\n").find { it.range == "a.rb:1-2" }
      expect([fragment.types.size, fragment.mass]).to(eq([15, 6]))
    end

    it "takes a rescue clause with no statements, or more than a report, for no report" do
      clauses = ["", " tracker.track(e)\n retry\n"].map { parsed("begin\n run\nrescue => e\n#{it}end\n").statements }
      recoveries = clauses.map { Hashira::Duplication::Recovery.new(it.body.first.rescue_clause) }
      expect(recoveries.map(&:reporting?)).to(all(be(false)))
    end
  end

  describe(Hashira::Duplication::NearMiss) do
    def listed(count) = Array.new(count) { " [x, [x, x], { x => x, x => [x, x] }, x, x]\n" }.join

    it "pairs two methods that call nothing on their shape, but never one that names nothing with one that does" do
      silent = { "a.rb" => "def a(x)\n#{listed(3)}end\n", "b.rb" => "def b(x)\n#{listed(3)} [x, x]\nend\n" }
      spoken = silent.merge("b.rb" => "def b(x)\n#{listed(3)} [x, y]\nend\n")
      expect([silent, spoken].map { clusters(it).size }).to(eq([1, 0]))
    end

    it "takes the words a method's strings and symbols carry as part of what it says" do
      envy = "refers to \#{names} more than to self, \#{detail[:count]} (\#{detail[:site]}). " \
        "The behavior may belong on \#{detail[:types]}."
      trace = "scores cognitive \#{detail[:cognitive]} with its \#{names} read in place (\#{detail[:site]}). " \
        "Inline the helpers that only move code."
      head = ->(name, key) { "def #{name}(finding)\n detail = finding.detail.to_h\n names = detail[:#{key}]\n" }
      said = ->(name, key, words) { "#{head[name, key]} \"\#{finding.package} #{words}\"\nend\n" }
      expect(clusters("a.rb" => said["a", "names", envy], "b.rb" => said["b", "helpers", trace])).to(be_empty)
    end

    def pair(*sources) = Hashira::Duplication::Pair.new(*sources.map { fragments("a.rb" => it).find(&:opened?) })

    def calls(names, argument = "1") = names.map { " x.#{it}(#{argument})\n" }.join

    it "takes the same calls in another order for other names, however alike their tallies" do
      names = %w[a b c d e f g h]
      shuffled = pair("def m(x)\n#{calls(names)}end\n", "def n(x)\n#{calls(names.reverse)} x.z\nend\n")
      expect([shuffled.named?, shuffled.drifted?]).to(eq([false, true]))
    end

    it "takes the same calls with different arguments for a different shape" do
      nested = calls(%w[a b c], "[[1, 2], { k: [3, 4] }]")
      reshaped = pair("def m(x)\n#{calls(%w[a b c])}end\n", "def n(x)\n#{nested}end\n")
      expect([reshaped.named?, reshaped.drifted?]).to(eq([true, false]))
    end
  end
end
