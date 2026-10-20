# frozen_string_literal: true

RSpec.describe(Hashira::Pipeline, "#findings") do
  def ring(size, extra)
    (1..size).to_h do |n|
      uses = "[C#{(n % size) + 1}::X, #{extra}]"
      ["lib/app/c#{n}/x.rb", "module App; module C#{n}; class X; def c = #{uses}; end; end; end\n"]
    end
  end

  def padded(files)
    stub = ->(folder, name) { "module App; module #{folder.capitalize}; class #{name}; end; end; end\n" }
    files.merge(%w[main/E main/F one/E].to_h { ["lib/app/#{it.downcase}.rb", stub.call(*it.split("/"))] })
  end

  def verdicts(files, directories: ["lib/app"])
    within(files) do
      yield(Hashira::Pipeline.new(Hashira::Project.new(directories, rules: Hashira::Config::Rules::ALL)).findings)
    end
  end
  it "reports cycles with members, a sample path, the cheapest cut, and its evidence" do
    verdicts(Fixtures::CYCLIC_FILES) do |all|
      cycles = all.select { it.kind == "cycle" }
      expect(cycles.map(&:package)).to(eq(%w[alpha]))
      finding = cycles.first
      expect(finding.cycle).to(eq(%w[alpha beta alpha]))
      expect(message(finding)).to(include("alpha and beta depend on each other in a cycle"))
      expect(message(finding)).to(include("The cheapest cut is alpha -> beta (1 ref)."))
      expect(finding.evidence).to(eq(["alpha/one.rb:4: Beta::Two"]))
    end
  end

  it "reports each distinct loop once, from its smallest member" do
    verdicts(Fixtures::CYCLIC_FILES) do |all|
      cycles = all.select { it.kind == "cycle" }
      expect(cycles.size).to(eq(1))
      expect(cycles.first.package).to(eq("alpha"))
    end
  end

  it "reports every distinct loop, one finding each" do
    files = {
      "lib/app/a/x.rb" => "module App; module A; class X; def c = B::X; end; end; end\n",
      "lib/app/b/x.rb" => "module App; module B; class X; def c = A::X; end; end; end\n",
      "lib/app/c/x.rb" => "module App; module C; class X; def c = D::X; end; end; end\n",
      "lib/app/d/x.rb" => "module App; module D; class X; def c = C::X; end; end; end\n"
    }
    verdicts(files) do |all|
      expect(all.select { it.kind == "cycle" }.map(&:cycle)).to(eq([%w[a b a], %w[c d c]]))
    end
  end

  it "names the cheapest cut wherever it sits on the cycle" do
    files = {
      "lib/app/a/x.rb" => "module App; module A; class X; def c = [B::X, B::Y]; end; end; end\n",
      "lib/app/b/x.rb" => "module App; module B; class X; def c = A::X; end; end; end\n"
    }
    verdicts(files) do |all|
      cycle = all.find { it.kind == "cycle" }
      expect(message(cycle)).to(include("The cheapest cut is b -> a (1 ref)."))
    end
  end

  it "cuts the edge out of the package more others depend on when the weights tie" do
    files = {
      "lib/app/post/x.rb" => "module App; module Post; class X; def c = User::X; end; end; end\n",
      "lib/app/user/x.rb" => "module App; module User; class X; def c = Post::X; end; end; end\n",
      "lib/app/tag/x.rb" => "module App; module Tag; class X; def c = User::X; end; end; end\n",
      "lib/app/vote/x.rb" => "module App; module Vote; class X; def c = User::X; end; end; end\n"
    }
    verdicts(files) do |all|
      expect(message(all.find { it.kind == "cycle" })).to(include("The cheapest cut is user -> post (1 ref)."))
    end
  end

  def cascade(user, post = "belongs_to :user")
    {
      "config/application.rb" => "module Shop; class Application; end; end\n",
      "app/models/user.rb" => "class User\n  #{user}\nend\n",
      "app/models/post.rb" => "class Post\n  #{post}\nend\n",
      "app/models/session.rb" => "class Session\n  belongs_to :user\nend\n"
    }
  end

  def carried(files)
    verdicts(files, directories: ["app"]) { |all| return all.find { it.kind == "cycle" } }
  end

  it "names the dependent: option an edge to cut carries, since cutting it drops what deleting the owner does" do
    cycle = carried(cascade("has_many :posts, dependent: :destroy"))
    pledge = "models/user.rb:2: has_many :posts, dependent: :destroy"
    expect(cycle.detail[:cut]).to(eq([{ from: "User", to: "Post", weight: 1, guarantees: [pledge] }]))
    said = "The cheapest cut is User -> Post (1 ref). User -> Post carries a dependent: option (has_many :posts, " \
      "dependent: :destroy at models/user.rb:2) — cutting it drops what deleting the owner does to its records, " \
      "so hand that to an object above both packages first."
    expect(message(cycle)).to(end_with(said))
  end

  it "says how many edges to cut carry a dependent: option, and that there are more than it shows" do
    user = "has_many :posts, dependent: :destroy\n  has_many :notes, dependent: :nullify"
    notes = { "app/models/note.rb" => "class Note\n  belongs_to :user\nend\n" }
    cycle = carried(cascade(user, "belongs_to :user\n  def n = Note").merge(notes))
    held = cycle.detail[:cut].map { [it[:from], it[:to], it[:guarantees].size] }
    expect(held).to(eq([["User", "Note", 1], ["User", "Post", 1]]))
    said = "2 of these edges carry a dependent: option (User -> Note: has_many :notes, dependent: :nullify at " \
      "models/user.rb:3, …) — cutting one drops"
    expect(message(cycle)).to(include(said))
  end

  it "marks a second dependent: option on the one edge to cut" do
    user = "has_many :posts, dependent: :destroy\n  has_many :drafts, class_name: \"Post\", dependent: :delete_all"
    post = "belongs_to :user\n  belongs_to :editor, class_name: \"User\""
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
    verdicts(ring(8, "C1::X")) do |all|
      cycles = all.select { it.kind == "cycle" }
      expect(cycles.map { [it.package, it.detail[:members].size] }).to(eq([["c1", 8]]))
      expect(message(cycles.first)).to(start_with("c1, c2, c3, c4, c5, c6 and 2 more depend on each other in a cycle"))
    end
  end

  it "lists a three-package knot in full" do
    verdicts(ring(3, "nil")) do |all|
      cycle = all.find { it.kind == "cycle" }
      expect(message(cycle)).to(start_with("c1, c2 and c3 depend on each other in a cycle"))
    end
  end

  it "plurals a multi-ref weakest edge" do
    files = {
      "lib/app/a/x.rb" => "module App; module A; class X; def c = [B::X, B::Y]; end; end; end\n",
      "lib/app/b/x.rb" => "module App; module B; class X; def c = [A::X, A::Y]; end; end; end\n"
    }
    verdicts(files) do |all|
      cycle = all.find { it.kind == "cycle" }
      expect(message(cycle)).to(include("(2 refs)."))
    end
  end

  it "names the members that are in a cycle only through what was folded into them" do
    alert = "module Billing\n  class Alert\n    def a = Notification\n  end\nend\n"
    files = Fixtures::RAILS_FILES.merge(Fixtures::NOTIFY_FILES, "app/models/billing/alert.rb" => alert)
    verdicts(files, directories: ["app"]) do |all|
      cycle = all.find { it.kind == "cycle" }
      expect(cycle.detail).to(include(members: %w[Billing Notification], folded: %w[Notification]))
      expect(message(cycle)).to(
        start_with("Billing and Notification depend on each other in a cycle (Notification is in it only through")
      )
    end
  end

  it "lists several fold-only members together, and none when the loop survives unfolded" do
    policy = "class BillingPolicy\n  def p = Notification\nend\n"
    files = Fixtures::RAILS_FILES.merge(Fixtures::NOTIFY_FILES, "app/policies/billing_policy.rb" => policy)
    loop = files.merge(
      "app/models/notification.rb" => "class Notification\n  def read = Billing::Invoice\nend\n",
      "app/models/billing/alert.rb" => "module Billing; class Alert; def a = Notification; end; end\n"
    )
    verdicts(files, directories: ["app"]) do |all|
      expect(message(all.find { it.kind == "cycle" })).to(include("(Billing and Notification are in it only through"))
    end
    verdicts(loop, directories: ["app"]) do |all|
      expect(all.find { it.kind == "cycle" }.detail[:folded]).to(eq([]))
    end
  end

  it "reports SDP violations with instabilities and evidence" do
    verdicts(Fixtures::UNSTABLE_FILES) do |all|
      violations = all.select { it.kind == "sdp_violation" }
      expect(violations.size).to(eq(1))
      finding = violations.first
      expect(finding.package).to(eq("stock"))
      expect(message(finding)).to(include("stock (I=0.33) depends on the LESS stable pricing (I=0.67)"))
      expect(finding.evidence).to(eq(["stock/x.rb:1: Pricing::X"]))
    end
  end

  it "leaves an edge inside a cycle to the cycle finding, not to SDP" do
    verdicts(Fixtures::CYCLIC_FILES) do |all|
      expect(all.map(&:kind)).not_to(include("sdp_violation"))
    end
  end

  it "needs at least three edges at each end before it trusts an instability" do
    leaner = Fixtures::UNSTABLE_FILES.except("lib/app/cart/x.rb")
    sparser = Fixtures::UNSTABLE_FILES.except("lib/app/rates/x.rb")
    [leaner, sparser].each do |files|
      verdicts(files) { |all| expect(all.map(&:kind)).not_to(include("sdp_violation")) }
    end
  end

  it "needs the instabilities to differ by at least a tenth" do
    source = ->(name, uses) { "module App; module #{name}; class X; def c = [#{uses}]; end; end; end\n" }
    tenth = Fixtures::UNSTABLE_FILES.merge(
      "lib/app/stock/x.rb" => source.call("Stock", "Pricing::X, Tax::X"),
      "lib/app/pricing/x.rb" => source.call("Pricing", "Tax::X, Rates::X, Fees::X"),
      "lib/app/fees/x.rb" => source.call("Fees", ""), "lib/app/fair/x.rb" => source.call("Fair", "Pricing::X")
    )
    even = tenth.merge("lib/app/mart/x.rb" => source.call("Mart", "Pricing::X"))
    verdicts(tenth) do |all|
      expect(all.select { it.kind == "sdp_violation" }.map { message(it)[/.*?\(.*?\(.*?\)/] })
        .to(eq(["stock (I=0.50) depends on the LESS stable pricing (I=0.60)"]))
    end
    verdicts(even) { |all| expect(all.map(&:kind)).not_to(include("sdp_violation")) }
  end

  it "reports a package whose clients split into audiences, naming the seam" do
    files = {
      "lib/app/core/walk.rb" => "module App; module Core; class Walk; def a = 1; end; end; end\n",
      "lib/app/core/score.rb" => "module App; module Core; class Score; def a = 1; end; end; end\n",
      "lib/app/core/graph.rb" => "module App; module Core; class Graph; def a = 1; end; end; end\n",
      "lib/app/core/chart.rb" => "module App; module Core; class Chart; def a = 1; end; end; end\n",
      "lib/app/one/a.rb" => "module App; module One; class A; def c = [Core::Walk, Core::Score]; end; end; end\n",
      "lib/app/two/b.rb" => "module App; module Two; class B; def c = [Core::Walk, Core::Score]; end; end; end\n",
      "lib/app/three/c.rb" => "module App; module Three; class C; def c = [Core::Walk, Core::Score]; end; end; end\n",
      "lib/app/main/d.rb" => "module App; module Main; class D; " \
        "def c = [App::Core::Graph, Core::Chart, Core::Score]; end; end; end\n"
    }
    message =
      "core splits 2 ways: main, one, three, two share Core::Score, Core::Walk; " \
        "main alone uses Core::Chart, Core::Graph — " \
        "parts with separate client bases are separate packages in disguise. " \
        "Split core along that seam, keeping the shared constants as the base layer the rest builds on."
    verdicts(padded(files)) do |all|
      finding = all.find { it.kind == "mixed_audience" }
      expect(finding.package).to(eq("core"))
      expect(message(finding)).to(eq(message))
      expect(finding.evidence).to(include("main/d.rb:1: App::Core::Graph"))
      expect(finding.evidence.size).to(eq(4))
    end
  end

  it "reports disjoint audiences without a shared base layer" do
    files = {
      "lib/app/core/walk.rb" => "module App; module Core; class Walk; def a = 1; end; end; end\n",
      "lib/app/core/score.rb" => "module App; module Core; class Score; def a = 1; end; end; end\n",
      "lib/app/core/graph.rb" => "module App; module Core; class Graph; def a = 1; end; end; end\n",
      "lib/app/core/chart.rb" => "module App; module Core; class Chart; def a = 1; end; end; end\n",
      "lib/app/one/a.rb" => "module App; module One; class A; def c = [Core::Walk, Core::Score]; end; end; end\n",
      "lib/app/two/b.rb" => "module App; module Two; class B; def c = [Core::Walk, Core::Score]; end; end; end\n",
      "lib/app/three/c.rb" => "module App; module Three; class C; def c = [Core::Graph, Core::Chart]; end; end; end\n",
      "lib/app/main/d.rb" => "module App; module Main; class D; def c = [Core::Graph, Core::Chart]; end; end; end\n"
    }
    message =
      "core splits 2 ways: main, three use Core::Chart, Core::Graph; " \
        "one, two use Core::Score, Core::Walk — " \
        "parts with separate client bases are separate packages in disguise. " \
        "Split core along that seam."
    verdicts(padded(files)) do |all|
      finding = all.find { it.kind == "mixed_audience" }
      expect(message(finding)).to(eq(message))
    end
  end

  it "does not count the root package as an audience" do
    type = ->(name) { "module App; module Core; class #{name}; end; end; end" }
    core = %w[Walk Score Graph Chart].to_h { ["lib/app/core/#{it}.rb", type.call(it)] }
    files = core.merge(
      "lib/app/one/a.rb" => "module App; module One; class A; def c = [Core::Walk, Core::Score]; end; end; end\n",
      "lib/app/two/b.rb" => "module App; module Two; class B; def c = [Core::Walk, Core::Score]; end; end; end\n",
      "lib/app/boot.rb" => "module App; class Boot; def c = [Core::Graph, Core::Chart]; end; end",
      "lib/app/boot_extra.rb" => "module App; class E; end; class F; end; end"
    )
    named = files.except("lib/app/boot.rb").merge(
      "lib/app/main/d.rb" => "module App; module Main; class D; def c = [Core::Graph, Core::Chart]; end; end; end\n"
    )
    verdicts(padded(files)) { |all| expect(all.map(&:kind)).not_to(include("mixed_audience")) }
    verdicts(padded(named)) { |all| expect(all.map(&:kind)).to(include("mixed_audience")) }
  end

  it "backs an audience with evidence when its clients reach only nested constants" do
    files = {
      "lib/app/core/walk.rb" => "module App; module Core; class Walk; LIMIT = 1; end; end; end\n",
      "lib/app/core/score.rb" => "module App; module Core; class Score; LIMIT = 1; end; end; end\n",
      "lib/app/core/graph.rb" => "module App; module Core; class Graph; def a = 1; end; end; end\n",
      "lib/app/core/chart.rb" => "module App; module Core; class Chart; def a = 1; end; end; end\n",
      "lib/app/one/a.rb" =>
        "module App; module One; class A; def c = [Core::Walk::LIMIT, Core::Score::LIMIT]; end; end; end\n",
      "lib/app/two/b.rb" =>
        "module App; module Two; class B; def c = [Core::Walk::LIMIT, Core::Score::LIMIT]; end; end; end\n",
      "lib/app/three/c.rb" => "module App; module Three; class C; def c = [Core::Graph, Core::Chart]; end; end; end\n",
      "lib/app/main/d.rb" => "module App; module Main; class D; def c = [Core::Graph, Core::Chart]; end; end; end\n"
    }
    verdicts(padded(files)) do |all|
      finding = all.find { it.kind == "mixed_audience" }
      expect(finding.evidence).to(
        eq(["main/d.rb:1: Core::Graph", "main/d.rb:1: Core::Chart", "one/a.rb:1: Core::Walk::LIMIT", "one/a.rb:1: Core::Score::LIMIT"])
      )
    end
  end

  it "reports an edge too wide for one interface" do
    files = {
      "lib/app/core/a.rb" => "module App; module Core; class A; def a = 1; end; end; end\n",
      "lib/app/core/b.rb" => "module App; module Core; class B; def a = 1; end; end; end\n",
      "lib/app/core/c.rb" => "module App; module Core; class C; def a = 1; end; end; end\n",
      "lib/app/core/d.rb" => "module App; module Core; class D; def a = 1; end; end; end\n",
      "lib/app/core/e.rb" => "module App; module Core; class E; def a = 1; end; end; end\n",
      "lib/app/main/uses.rb" =>
        "module App; module Main; class Uses; def go = [Core::A, Core::B, Core::C, Core::D, Core::E]; end; end; end\n"
    }
    expected =
      "main -> core is 5 constants wide (Core::A, Core::B, Core::C, Core::D, Core::E) — " \
        "every one is a reason for main to change. Front core with one facade."
    verdicts(files) do |all|
      finding = all.find { it.kind == "wide_edge" }
      expect(finding.package).to(eq("main"))
      expect(finding.digest).to(eq("main -> core"))
      expect(message(finding)).to(eq(expected))
      expect(finding.evidence.size).to(eq(4))
    end
  end

  it "counts a constant once however it is spelled, relative or qualified" do
    core = %w[Error Blob Clock Opts More].to_h { ["lib/app/#{it.downcase}.rb", "module App; class #{it}; end; end"] }
    uses = ->(list) { "module App; module Adapters; class Pg; def go = [#{list}]; end; end; end\n" }
    files = core.merge("lib/app/helpers.rb" => "module AppHelpers; end\n")
    spelled = "Error, App::Error, Blob, ::App::Blob, Clock, App::Clock"
    verdicts(files.merge("lib/app/adapters/pg.rb" => uses.call(spelled))) do |all|
      expect(all.map(&:kind)).not_to(include("wide_edge"))
    end
    verdicts(files.merge("lib/app/adapters/pg.rb" => uses.call("#{spelled}, Opts, App::More"))) do |all|
      expect(all.find { it.kind == "wide_edge" }.detail[:constants])
        .to(eq(%w[App::Blob App::Clock App::Error App::More App::Opts]))
    end
  end

  it "counts a class and the types nested in it as one constant of an edge" do
    gate = "module App; module Core; class Gate; class Policy; end; class Exceeded; end; end; end; end\n"
    kit = "module App; module Core; module Kit; class One; end; class Two; end; end; end; end\n"
    core = %w[A B C].to_h { ["lib/app/core/#{it.downcase}.rb", "module App; module Core; class #{it}; end; end; end"] }
    uses = ->(list) { "module App; module Main; class Uses; def go = [#{list}]; end; end; end\n" }
    files = core.merge("lib/app/core/gate.rb" => gate, "lib/app/core/kit.rb" => kit)
    main = ->(list) { files.merge("lib/app/main/uses.rb" => uses.call("#{list}, Core::A, Core::B")) }
    one = main.call("Core::Gate, Core::Gate::Policy, Core::Gate::Exceeded")
    loose = main.call("Core::Gate::Policy, Core::Gate::Exceeded, Core::C")
    kits = main.call("Core::Kit, Core::Kit::One, Core::Kit::Two")
    verdicts(one) { |all| expect(all.map(&:kind)).not_to(include("wide_edge")) }
    verdicts(loose) do |all|
      expect(all.find { it.kind == "wide_edge" }.detail[:constants])
        .to(eq(%w[Core::A Core::B Core::C Core::Gate::Exceeded Core::Gate::Policy]))
    end
    verdicts(kits) { |all| expect(all.find { it.kind == "wide_edge" }.detail[:constants].size).to(eq(5)) }
  end

  it "leaves the presentation layer's edge into the domain it exposes out of wide edges" do
    billing = %w[A B C D E].to_h { ["app/models/billing/#{it.downcase}.rb", "module Billing; class #{it}; end; end\n"] }
    reach = "[Billing::A, Billing::B, Billing::C, Billing::D, Billing::E]"
    files = billing.merge(
      "config/application.rb" => "module Shop; class Application; end; end\n",
      "app/models/order.rb" => "class Order\n  def bill = #{reach}\nend\n",
      "app/controllers/bills_controller.rb" => "class BillsController\n  def index = #{reach}\nend\n"
    )
    verdicts(files, directories: ["app"]) do |all|
      expect(all.select { it.kind == "wide_edge" }.map(&:digest)).to(eq(["Order -> Billing"]))
    end
  end

  it "reports a roll-call of words kept in sync across packages" do
    files = {
      "lib/app/one/a.rb" => "module One; class A; KINDS = %w[red blue lime]; def a = KINDS; end; end\n",
      "lib/app/two/b.rb" => "module Two; class B; KINDS = %i[red blue lime]; def a = KINDS; end; end\n",
      "lib/app/three/c.rb" =>
        "module App; module Three; class C; MAP = { \"red\" => 1, blue: 2, lime: 3 }; def a = MAP; end; end; end\n"
    }
    expected =
      "the words blue, lime, red are listed together in one/a.rb, three/c.rb, two/b.rb — " \
        "3 packages keep one roll-call in sync by hand. Make the list data with a single owner."
    verdicts(files) do |all|
      finding = all.find { it.kind == "roll_call" }
      expect(finding.digest).to(eq("blue,lime,red"))
      expect(message(finding)).to(eq(expected))
      expect(finding.evidence).to(eq(["one/a.rb:1", "three/c.rb:1", "two/b.rb:1"]))
    end
  end

  it "leaves a Rails app's lists of REST actions out of roll-calls, since Rails owns those words" do
    app = {
      "config/application.rb" => "module Shop; class Application; end; end\n",
      "app/controllers/application_controller.rb" => "class ApplicationController; end\n"
    }
    names = %w[One Two Three]
    rolls =
      %w[red show].map do |first|
        files = names.to_h { ["app/models/#{it.downcase}/a.rb", "module #{it}; A = %i[#{first} edit update]; end\n"] }
        verdicts(app.merge(files), directories: ["app"]) { |all| all.select { it.kind == "roll_call" }.map(&:digest) }
      end
    expect(rolls).to(eq([["edit,red,update"], []]))
  end

  it "lists findings in rule order" do
    verdicts(Fixtures::CYCLIC_FILES.merge(Fixtures::UNSTABLE_FILES)) do |all|
      expect(all.map(&:kind).uniq).to(eq(%w[cycle sdp_violation utility_function]))
    end
  end
end
