# frozen_string_literal: true

RSpec.describe(Hashira::Pipeline, "#findings", :aggregate_failures) do
  def ring(size, extra)
    (1..size).to_h do |n|
      uses = "[C#{(n % size) + 1}::X, #{extra}]"
      ["lib/app/c#{n}/x.rb", "module App; module C#{n}; class X; def c = #{uses}; end; end; end\n"]
    end
  end

  def stub(folder, name) = "module App; module #{folder.capitalize}; class #{name}; end; end; end\n"

  def padded(files) = files.merge(%w[main/E main/F one/E].to_h { ["lib/app/#{it.downcase}.rb", stub(*it.split("/"))] })

  def verdicts(files, directories: ["lib/app"])
    within(files) { Hashira::Pipeline.new(Hashira::Project.new(directories, rules: Hashira::Config::Rules::ALL)).findings }
  end

  def found(files, kind, **) = verdicts(files, **).select { it.kind == kind }

  def first(files, kind, **) = found(files, kind, **).first

  def kinds(files, **) = verdicts(files, **).map(&:kind)

  it "reports cycles with members, a sample path, the cheapest cut, and its evidence" do
    cycles = found(Fixtures::CYCLIC_FILES, "cycle")
    expect(cycles.map { [it.package, it.cycle, it.evidence] }).to(
      eq([["alpha", %w[alpha beta alpha], ["alpha/one.rb:4: Beta::Two"]]])
    )
    expect(message(cycles.first)).to(
      include("alpha and beta depend on each other in a cycle", "The cheapest cut is alpha -> beta (1 ref).")
    )
  end

  it "reports each distinct loop once, from its smallest member" do
    expect(found(Fixtures::CYCLIC_FILES, "cycle").map(&:package)).to(eq(%w[alpha]))
  end

  it "reports every distinct loop, one finding each" do
    files = {
      "lib/app/a/x.rb" => "module App; module A; class X; def c = B::X; end; end; end\n",
      "lib/app/b/x.rb" => "module App; module B; class X; def c = A::X; end; end; end\n",
      "lib/app/c/x.rb" => "module App; module C; class X; def c = D::X; end; end; end\n",
      "lib/app/d/x.rb" => "module App; module D; class X; def c = C::X; end; end; end\n"
    }
    expect(found(files, "cycle").map(&:cycle)).to(eq([%w[a b a], %w[c d c]]))
  end

  it "names the cheapest cut wherever it sits on the cycle" do
    files = {
      "lib/app/a/x.rb" => "module App; module A; class X; def c = [B::X, B::Y]; end; end; end\n",
      "lib/app/b/x.rb" => "module App; module B; class X; def c = A::X; end; end; end\n"
    }
    expect(message(first(files, "cycle"))).to(include("The cheapest cut is b -> a (1 ref)."))
  end

  it "cuts the edge out of the package more others depend on when the weights tie" do
    files = {
      "lib/app/post/x.rb" => "module App; module Post; class X; def c = User::X; end; end; end\n",
      "lib/app/user/x.rb" => "module App; module User; class X; def c = Post::X; end; end; end\n",
      "lib/app/tag/x.rb" => "module App; module Tag; class X; def c = User::X; end; end; end\n",
      "lib/app/vote/x.rb" => "module App; module Vote; class X; def c = User::X; end; end; end\n"
    }
    expect(message(first(files, "cycle"))).to(include("The cheapest cut is user -> post (1 ref)."))
  end

  def cascade(user, post = "def owner = User")
    {
      "config/application.rb" => "module Shop; class Application; end; end\n",
      "app/models/user.rb" => "class User\n  #{user}\nend\n",
      "app/models/post.rb" => "class Post\n  #{post}\nend\n",
      "app/models/session.rb" => "class Session\n  belongs_to :user\nend\n"
    }
  end

  def carried(files) = first(files, "cycle", directories: ["app"])

  it "names the dependent: option an edge to cut carries, since cutting it drops what deleting the owner does" do
    cycle = carried(cascade("has_many :posts, dependent: :destroy"))
    pledge = "models/user.rb:2: has_many :posts, dependent: :destroy"
    expect(cycle.detail[:cut]).to(eq([{ from: "User", to: "Post", weight: 1, guarantees: [pledge] }]))
    expect(message(cycle)).to(end_with(<<~TEXT.tr("\n", " ").strip))
      The cheapest cut is User -> Post (1 ref). User -> Post carries a dependent: option (has_many :posts,
      dependent: :destroy at models/user.rb:2) — cutting it drops what deleting the owner does to its records,
      so hand that to an object above both packages first.
    TEXT
  end

  it "says how many edges to cut carry a dependent: option, and that there are more than it shows" do
    user = "has_many :posts, dependent: :destroy\n  has_many :notes, dependent: :nullify"
    notes = { "app/models/note.rb" => "class Note\n  def owner = User\nend\n" }
    cycle = carried(cascade(user, "def owner = User\n  def n = Note").merge(notes))
    expect(cycle.detail[:cut].map { [it[:from], it[:to], it[:guarantees].size] }).to(
      eq([["User", "Note", 1], ["User", "Post", 1]])
    )
    expect(message(cycle)).to(include(<<~TEXT.tr("\n", " ").strip))
      2 of these edges carry a dependent: option (User -> Note: has_many :notes, dependent: :nullify at
      models/user.rb:3, …) — cutting one drops
    TEXT
  end

  it "marks a second dependent: option on the one edge to cut" do
    user = "has_many :posts, dependent: :destroy\n  has_many :drafts, class_name: \"Post\", dependent: :delete_all"
    post = "def owner = User\n  def editor = User"
    expect(message(carried(cascade(user, post)))).to(
      include("User -> Post carries a dependent: option (has_many :posts, dependent: :destroy at models/user.rb:2, …)")
    )
  end

  it "takes dependent: nil for no option at all" do
    cycle = carried(cascade("has_many :posts, dependent: nil"))
    expect([cycle.detail[:cut], message(cycle)[/cut is .*/]]).to(
      eq([[{ from: "User", to: "Post", weight: 1 }], "cut is User -> Post (1 ref)."])
    )
  end

  it "reports a knot of packages once, from its smallest member, whatever loops run through it" do
    cycles = found(ring(8, "C1::X"), "cycle")
    expect(cycles.map { [it.package, it.detail[:members].size] }).to(eq([["c1", 8]]))
    expect(message(cycles.first)).to(start_with("c1, c2, c3, c4, c5, c6 and 2 more depend on each other in a cycle"))
  end

  it "lists a three-package knot in full" do
    expect(message(first(ring(3, "nil"), "cycle"))).to(start_with("c1, c2 and c3 depend on each other in a cycle"))
  end

  it "plurals a multi-ref weakest edge" do
    files = {
      "lib/app/a/x.rb" => "module App; module A; class X; def c = [B::X, B::Y]; end; end; end\n",
      "lib/app/b/x.rb" => "module App; module B; class X; def c = [A::X, A::Y]; end; end; end\n"
    }
    expect(message(first(files, "cycle"))).to(include("(2 refs)."))
  end

  it "names the members that are in a cycle only through what was folded into them" do
    alert = { "app/models/billing/alert.rb" => "module Billing\n  class Alert\n    def a = Notification\n  end\nend\n" }
    cycle = carried(Fixtures::RAILS_FILES.merge(Fixtures::NOTIFY_FILES, alert))
    expect(cycle.detail).to(include(members: %w[Billing Notification], folded: %w[Notification]))
    expect(message(cycle)).to(
      start_with("Billing and Notification depend on each other in a cycle (Notification is in it only through")
    )
  end

  it "lists several fold-only members together, and none when the loop survives unfolded" do
    policy = "class BillingPolicy\n  def p = Notification\nend\n"
    files = Fixtures::RAILS_FILES.merge(Fixtures::NOTIFY_FILES, "app/policies/billing_policy.rb" => policy)
    loop = files.merge(
      "app/models/notification.rb" => "class Notification\n  def read = Billing::Invoice\nend\n",
      "app/models/billing/alert.rb" => "module Billing; class Alert; def a = Notification; end; end\n"
    )
    expect(message(carried(files))).to(include("(Billing and Notification are in it only through"))
    expect(carried(loop).detail[:folded]).to(eq([]))
  end

  it "reports SDP violations with instabilities and evidence" do
    violations = found(Fixtures::UNSTABLE_FILES, "unstable_dependency")
    expect(violations.map { [it.package, it.evidence] }).to(eq([["stock", ["stock/x.rb:1: Pricing::X"]]]))
    expect(message(violations.first)).to(include("stock (I=0.33) depends on the LESS stable pricing (I=0.67)"))
  end

  it "leaves an edge inside a cycle to the cycle finding, not to SDP" do
    expect(kinds(Fixtures::CYCLIC_FILES)).not_to(include("unstable_dependency"))
  end

  it "needs at least three edges at each end before it trusts an instability" do
    leaner = Fixtures::UNSTABLE_FILES.except("lib/app/cart/x.rb")
    sparser = Fixtures::UNSTABLE_FILES.except("lib/app/rates/x.rb")
    expect([leaner, sparser].flat_map { kinds(it) }).not_to(include("unstable_dependency"))
  end

  def unit(name, uses) = "module App; module #{name}; class X; def c = [#{uses}]; end; end; end\n"

  it "needs the instabilities to differ by at least a tenth" do
    tenth = Fixtures::UNSTABLE_FILES.merge(
      "lib/app/stock/x.rb" => unit("Stock", "Pricing::X, Tax::X"),
      "lib/app/pricing/x.rb" => unit("Pricing", "Tax::X, Rates::X, Fees::X"),
      "lib/app/fees/x.rb" => unit("Fees", ""), "lib/app/fair/x.rb" => unit("Fair", "Pricing::X")
    )
    expect(found(tenth, "unstable_dependency").map { message(it)[/.*?\(.*?\(.*?\)/] })
      .to(eq(["stock (I=0.50) depends on the LESS stable pricing (I=0.60)"]))
    even = tenth.merge("lib/app/mart/x.rb" => unit("Mart", "Pricing::X"))
    expect(kinds(even)).not_to(include("unstable_dependency"))
  end

  def core(names = %w[Walk Score Graph Chart], body = "def a = 1")
    names.to_h { ["lib/app/core/#{it.downcase}.rb", "module App; module Core; class #{it}; #{body}; end; end; end\n"] }
  end

  # A class in one folder of lib/app, using the constants listed.
  def client(path, uses)
    package, name = path.delete_suffix(".rb").split("/").map(&:capitalize)
    ["lib/app/#{path}", "module App; module #{package}; class #{name}; def c = [#{uses}]; end; end; end\n"]
  end

  def clients(uses) = uses.to_h { |path, list| client(path, list) }

  it "reports a package whose clients split into audiences, naming the seam" do
    uses = %w[one/a.rb two/b.rb three/c.rb].to_h { [it, "Core::Walk, Core::Score"] }
    files = core.merge(clients(uses.merge("main/d.rb" => "App::Core::Graph, Core::Chart, Core::Score")))
    finding = first(padded(files), "mixed_audience")
    expect([finding.package, message(finding), finding.evidence.size]).to(eq(["core", <<~TEXT.tr("\n", " ").strip, 4]))
      core splits 2 ways: main, one, three, two share Core::Score, Core::Walk; main alone uses Core::Chart,
      Core::Graph — parts with separate client bases are separate packages in disguise. Split core along that
      seam, keeping the shared constants as the base layer the rest builds on.
    TEXT
    expect(finding.evidence).to(include("main/d.rb:1: App::Core::Graph"))
  end

  # Two clients use the constants given, two others Core::Graph and Core::Chart.
  def split(uses)
    other = "Core::Graph, Core::Chart"
    clients("one/a.rb" => uses, "two/b.rb" => uses, "three/c.rb" => other, "main/d.rb" => other)
  end

  it "reports disjoint audiences without a shared base layer" do
    files = core.merge(split("Core::Walk, Core::Score"))
    expect(message(first(padded(files), "mixed_audience"))).to(eq(<<~TEXT.tr("\n", " ").strip))
      core splits 2 ways: main, three use Core::Chart, Core::Graph; one, two use Core::Score, Core::Walk —
      parts with separate client bases are separate packages in disguise. Split core along that seam.
    TEXT
  end

  it "does not count the root package as an audience" do
    files = core.merge(
      clients("one/a.rb" => "Core::Walk, Core::Score", "two/b.rb" => "Core::Walk, Core::Score"),
      "lib/app/boot.rb" => "module App; class Boot; def c = [Core::Graph, Core::Chart]; end; end",
      "lib/app/boot_extra.rb" => "module App; class E; end; class F; end; end"
    )
    named = files.except("lib/app/boot.rb").merge(clients("main/d.rb" => "Core::Graph, Core::Chart"))
    expect([files, named].map { kinds(padded(it)).include?("mixed_audience") }).to(eq([false, true]))
  end

  it "backs an audience with evidence when its clients reach only nested constants" do
    files = core.merge(core(%w[Walk Score], "LIMIT = 1"), split("Core::Walk::LIMIT, Core::Score::LIMIT"))
    expect(first(padded(files), "mixed_audience").evidence).to(
      eq(
        [
          "main/d.rb:1: Core::Graph", "main/d.rb:1: Core::Chart",
          "one/a.rb:1: Core::Walk::LIMIT", "one/a.rb:1: Core::Score::LIMIT"
        ]
      )
    )
  end

  it "reports an edge too wide for one interface" do
    files = core(%w[A B C D E]).merge(clients("main/uses.rb" => "Core::A, Core::B, Core::C, Core::D, Core::E"))
    finding = first(files, "wide_edge")
    expect([finding.package, finding.digest, message(finding), finding.evidence.size]).to(
      eq(["main", "main -> core", <<~TEXT.tr("\n", " ").strip, 4])
        main -> core is 5 constants wide (Core::A, Core::B, Core::C, Core::D, Core::E) — every one is a reason for
        main to change. Front core with one facade.
      TEXT
    )
  end

  def adapter(list) = clients("adapters/pg.rb" => list)

  it "counts a constant once however it is spelled, relative or qualified" do
    files = %w[Error Blob Clock Opts More].to_h { ["lib/app/#{it.downcase}.rb", "module App; class #{it}; end; end"] }
      .merge("lib/app/helpers.rb" => "module AppHelpers; end\n")
    spelled = "Error, App::Error, Blob, ::App::Blob, Clock, App::Clock"
    expect(kinds(files.merge(adapter(spelled)))).not_to(include("wide_edge"))
    expect(first(files.merge(adapter("#{spelled}, Opts, App::More")), "wide_edge").detail[:constants])
      .to(eq(%w[App::Blob App::Clock App::Error App::More App::Opts]))
  end

  def nested(list)
    core(%w[A B C]).merge(
      clients("main/uses.rb" => "#{list}, Core::A, Core::B"),
      "lib/app/core/gate.rb" => holder("class Gate", "class Policy; end; class Exceeded; end"),
      "lib/app/core/kit.rb" => holder("module Kit", "class One; end; class Two; end")
    )
  end

  def holder(opening, inner) = "module App; module Core; #{opening}; #{inner}; end; end; end\n"

  it "counts a class and the types nested in it as one constant of an edge" do
    expect(kinds(nested("Core::Gate, Core::Gate::Policy, Core::Gate::Exceeded"))).not_to(include("wide_edge"))
    loose = nested("Core::Gate::Policy, Core::Gate::Exceeded, Core::C")
    kits = nested("Core::Kit, Core::Kit::One, Core::Kit::Two")
    expect([loose, kits].map { first(it, "wide_edge").detail[:constants] }).to(
      match([eq(%w[Core::A Core::B Core::C Core::Gate::Exceeded Core::Gate::Policy]), have_attributes(size: 5)])
    )
  end

  it "leaves the presentation layer's edge into the domain it exposes out of wide edges" do
    billing = %w[A B C D E].to_h { ["app/models/billing/#{it.downcase}.rb", "module Billing; class #{it}; end; end\n"] }
    reach = "[Billing::A, Billing::B, Billing::C, Billing::D, Billing::E]"
    files = billing.merge(
      "config/application.rb" => "module Shop; class Application; end; end\n",
      "app/models/order.rb" => "class Order\n  def bill = #{reach}\nend\n",
      "app/controllers/bills_controller.rb" => "class BillsController\n  def index = #{reach}\nend\n"
    )
    expect(found(files, "wide_edge", directories: ["app"]).map(&:digest)).to(eq(["Order -> Billing"]))
  end

  it "reports a roll-call of words kept in sync across packages" do
    files = {
      "lib/app/one/a.rb" => "module One; class A; KINDS = %w[red blue lime]; def a = KINDS; end; end\n",
      "lib/app/two/b.rb" => "module Two; class B; KINDS = %i[red blue lime]; def a = KINDS; end; end\n",
      "lib/app/three/c.rb" =>
        "module App; module Three; class C; MAP = { \"red\" => 1, blue: 2, lime: 3 }; def a = MAP; end; end; end\n"
    }
    finding = first(files, "roll_call")
    expect([finding.digest, message(finding), finding.evidence]).to(
      eq(["blue,lime,red", <<~TEXT.tr("\n", " ").strip, ["one/a.rb:1", "three/c.rb:1", "two/b.rb:1"]])
        the words blue, lime, red are listed together in one/a.rb, three/c.rb, two/b.rb — 3 packages keep one
        roll-call in sync by hand. Make the list data with a single owner.
      TEXT
    )
  end

  def listing(name, first) = ["app/models/#{name.downcase}/a.rb", "module #{name}; A = %i[#{first} edit update]; end\n"]

  def rolls(first)
    app = {
      "config/application.rb" => "module Shop; class Application; end; end\n",
      "app/controllers/application_controller.rb" => "class ApplicationController; end\n"
    }
    files = %w[One Two Three].to_h { listing(it, first) }
    found(app.merge(files), "roll_call", directories: ["app"]).map(&:digest)
  end

  it "leaves a Rails app's lists of REST actions out of roll-calls, since Rails owns those words" do
    expect(%w[red show].map { rolls(it) }).to(eq([["edit,red,update"], []]))
  end

  it "lists findings in rule order" do
    expect(kinds(Fixtures::CYCLIC_FILES.merge(Fixtures::UNSTABLE_FILES)).uniq).to(
      eq(%w[cycle unstable_dependency utility_function])
    )
  end
end
