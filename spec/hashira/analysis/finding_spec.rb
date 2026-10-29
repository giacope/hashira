# frozen_string_literal: true

RSpec.describe(Hashira::Analysis::Finding, :aggregate_failures) do
  def site = "cart.rb:12"

  def smell(kind, detail) = handmade(kind, "Cart#price", detail)

  def spot(said, advice) = Hashira::Smells::Spot.new(site, said, advice)

  def envy(names, types, count) = Hashira::Smells::FeatureEnvy::Envy.new(site, names, types, balance(count))

  def balance(count) = Hashira::Smells::FeatureEnvy::Balance.new(count, 1)

  def assumed(installed, unassigned) = Hashira::Smells::AssumedState::Assumption.new(site, installed, unassigned)

  def dispatch(via) = Hashira::Smells::ManualDispatch::Dispatch.new(site, via)

  def doubt(origin) = Hashira::Smells::Doubt.new(site, origin, {})

  def smells
    {
      smell("control_parameter", Hashira::Smells::ControlParameter::Steering.new(site, %w[quoted])) =>
        "Cart#price is steered by 'quoted' (cart.rb:12). Split the method, or pass a strategy instead of a flag.",
      smell("data_clump", spot("passes the same parameters between methods", "Introduce a parameter object.")) =>
        "Cart#price passes the same parameters between methods (cart.rb:12). Introduce a parameter object.",
      smell("repeated_call", Hashira::Smells::RepeatedCall::Calls.new(site, 1, 2)) =>
        "Cart#price repeats 2 calls in 1 method (cart.rb:12). Name the result in a local variable.",
      smell("feature_envy", envy(%w[item], %w[item], 3)) =>
        "Cart#price refers to 'item' more than to self, 3 to 1 (cart.rb:12). The behavior may belong on item.",
      smell("feature_envy", envy(%w[item order line], %w[Item Order Line], 2)) =>
        "Cart#price refers to 'item', 'order', 'line' more than to self, 2 each to 1 (cart.rb:12). " \
        "The behavior may belong on Item, Order or Line."
    }
  end

  def absences
    {
      smell("assumed_state", assumed([], %w[@a])) =>
        "Cart#price reads instance variables nothing in the class assigns (cart.rb:12). " \
        "Nothing ever assigns '@a', so it reads nil: a typo or a dead hook. " \
        "Assign it where the object is built, or delete the read.",
      smell("assumed_state", assumed(%w[@a @b], [])) =>
        "Cart#price reads instance variables nothing in the class assigns (cart.rb:12). " \
        "Its subclasses are expected to install '@a', '@b'; pass them in instead.",
      smell("assumed_state", assumed(%w[@a], %w[@b @c])) =>
        "Cart#price reads instance variables nothing in the class assigns (cart.rb:12). " \
        "Nothing ever assigns '@b', '@c', so they read nil: a typo or a dead hook. " \
        "Assign them where the object is built, or delete the read. " \
        "Its subclasses are expected to install '@a'; pass it in instead.",
      smell("manual_dispatch", dispatch(["respond_to?"])) =>
        "Cart#price dispatches manually via respond_to? (cart.rb:12). " \
        "Trust the duck type, or split the callers into two adapters.",
      smell("manual_dispatch", dispatch(["a status switch"])) =>
        "Cart#price dispatches manually via a status switch (cart.rb:12). " \
        "Move each branch onto the type or state it tests, and let polymorphism pick."
    }
  end

  def nils
    {
      smell("nil_check", doubt(nil)) =>
        "Cart#price checks for nil (cart.rb:12). Prefer a default, a null object, or polymorphism.",
      smell("nil_check", doubt(:absence)) =>
        "Cart#price checks for nil (cart.rb:12). " \
        "Absence is the answer here, so ask for it: exists? instead of fetching a record to test for nil.",
      smell("repeated_conditional", Hashira::Smells::RepeatedConditional::Echoes.new(site, 3)) =>
        "Cart#price branches on the same test 3 times (cart.rb:12). Replace the scattered checks with polymorphism.",
      smell("state_sprawl", Hashira::Smells::StateSprawl::Sprawl.new(site, 5, [9, 8])) =>
        "Cart#price holds 5 instance variables, weighing 9, more than 8 (cart.rb:12). " \
        "Split the class, or gather related fields into value objects."
    }
  end

  def purity
    {
      smell("stateful_mixin", Hashira::Smells::StatefulMixin::Mixing.new(site, 2)) =>
        "Cart#price mixes behavior into its host's own state (cart.rb:12). " \
        "Make it a decorator: wrap the host and reach it through its public methods.",
      smell("nil_check", doubt(%w[coupon label])) =>
        "Cart#price checks for nil (cart.rb:12). 'coupon', 'label' default to nil, so callers may pass nothing " \
        "and the method is two in one: split it, or ask for a null object instead of nil.",
      smell("nil_check", Hashira::Smells::Doubt::Suspect.new(site, 2, nil)) =>
        "Cart#price may be nil, and 2 methods check for it (cart.rb:12). " \
        "Prefer a default, a null object, or polymorphism. Settle it where the nil is made."
    }
  end

  it "names the method a smell sits in, where it is, and what to do about it" do
    smells.merge(absences, nils, purity).each { |finding, said| expect(message(finding)).to(eq(said)) }
  end

  def effort
    Hashira::Complexity::MethodFinding::Effort.new(cognitive: 10, calls: 12, site: "shop.rb:4", dominant: "elsif")
  end

  it "names the site of a complex method, and the advice its dominant construct earns" do
    expect(message(handmade("complexity", "Shop#total", effort))).to(
      eq(
        "Shop#total — cognitive 10, 12 calls (shop.rb:4). " \
          "replace the elsif ladder with a lookup or polymorphic dispatch."
      )
    )
  end

  def clone(kind, hot:)
    handmade("duplication", "a.rb:1", Hashira::Duplication::DuplicationFinding::Overlap.new(3, 45, kind, hot))
  end

  it "says how a clone family varies" do
    expect(message(clone(:literal, hot: false))).to(
      eq("3 similar fragments (mass 45) — differs only in literal values — extract a method, pass them as arguments.")
    )
  end

  it "keeps every method name when the renamed copies differ inside too, rather than passing names as arguments" do
    said = "differs in its method names and in literal values — keep each name, calling one shared method"
    expect(message(clone(:renamed_literal, hot: false))).to(end_with("#{said} that takes the literals as arguments."))
  end

  it "asks for one decision about nil when the copies differ only in a safe navigation" do
    expect(%i[nil_guard renamed_nil_guard].map { message(clone(it, hot: false)) }).to(
      all(end_with("whether the receiver can be nil."))
    )
  end

  it "names a convention as one, by the sites that follow it" do
    expect(message(clone(:convention, hot: false))).to(
      start_with("3 sites follow one convention (mass 45) — a convention the code repeats on purpose")
    )
  end

  it "warns when both sites of a clone churn" do
    expect(message(clone(:identical, hot: true))).to(
      end_with("call it from each site. Both sites change often — fix one, miss the other.")
    )
  end

  it "names a long cut in part, with its total, and says when it is a best effort" do
    ties = Hashira::Coupling::Ties.new(("a".."h").map { [it, "z", 2] })
    ring = Hashira::Coupling::Cycle::Ring.new(%w[a z], [], ties, false)
    said = message(handmade("cycle", "a", ring))
    expect(said).to(include("The cheapest cut found is a -> z (2 refs)", "f -> z (2 refs) and 2 more (16 refs in all)"))
  end

  it "prints itself as its kind and package, its headline and evidence, and its JSON record" do
    finding = handmade("data_clump", "Cart#price", spot("passes", "Do it."), evidence: %w[one two], digests: ["d1"])
    expect([finding.to_s, finding.to_a]).to(
      eq(["data_clump/Cart#price", ["data_clump: Cart#price passes (cart.rb:12). Do it.", "one", "two"]])
    )
    expect(finding.to_h).to(
      eq(
        kind: "data_clump", package: "Cart#price", detail: { site: site }, evidence: %w[one two], digest: "d1",
        message: "Cart#price passes (cart.rb:12). Do it.", confidence: "medium"
      )
    )
  end

  it "flattens a detail object into plain data" do
    effort = Hashira::Complexity::MethodFinding::Effort.new(cognitive: 12, calls: 3, site: "a.rb:1", dominant: "if")
    flattened = { cognitive: 12, calls: 3, site: "a.rb:1", dominant: "if" }
    expect(handmade("complexity", "App#run", effort).to_h.except(:message)).to(
      eq(kind: "complexity", package: "App#run", detail: flattened, evidence: [], confidence: "high")
    )
  end

  def trace(finding) = mark_of(finding).trace

  it "traces by evidence where there is some, and by the shape of the code it names where there is none" do
    traced = ->(evidence) { trace(handmade("nil_check", "A#b", doubt(nil), evidence:, shapes: ["abc"])) }
    expect([traced[["x (line 3)"]], traced[[]]]).to(eq(["nil_check|cart.rb|x", "nil_check|cart.rb|abc"]))
  end

  it "keeps the shape out of the machine format, since only the ratchet reads it" do
    finding = handmade("nil_check", "A#b", Fakes::Detail.new({}), shapes: ["abc"])
    expect(finding.to_h).to(
      eq(kind: "nil_check", package: "A#b", detail: {}, evidence: [], message: "A#b ()", confidence: "medium")
    )
  end
end
