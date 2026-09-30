# frozen_string_literal: true

RSpec.describe(Hashira::Report::Phrases) do
  it "voices every finding kind the pipeline can emit, and no phantom kinds" do
    kinds = Hashira::CLI::FailOn::KINDS.values.flatten.uniq.sort
    voices = described_class.singleton_methods.grep(/\Aon_/).map { it.to_s.delete_prefix("on_") }.sort
    expect(voices).to(eq(kinds))
  end

  def smell(kind, **detail)
    Hashira::Analysis::Finding.new(kind:, package: "Cart#price", evidence: [], detail: { site: "cart.rb:12", **detail })
  end

  def smells
    {
      smell("control_parameter", names: %w[quoted]) =>
        "Cart#price is steered by 'quoted' (cart.rb:12). Split the method, or pass a strategy instead of a flag.",
      smell("data_clump") =>
        "Cart#price passes the same parameters between methods (cart.rb:12). Introduce a parameter object.",
      smell("repeated_call") => "Cart#price repeats identical calls (cart.rb:12). Name the result in a local variable.",
      smell("feature_envy", names: %w[item order]) =>
        "Cart#price refers to 'item', 'order' more than to self (cart.rb:12). The behavior may belong on item.",
      smell("assumed_state") =>
        "Cart#price reads instance variables nothing in the class assigns (cart.rb:12). " \
        "Assign them where the object is built, or pass the data explicitly.",
      smell("manual_dispatch") =>
        "Cart#price dispatches manually via respond_to? (cart.rb:12). " \
        "Trust the duck type, or split the callers into two adapters.",
      smell("module_initialize") =>
        "Cart#price defines initialize in a module (cart.rb:12). " \
        "A mixin that carries constructor state is implementation inheritance; compose a collaborator instead.",
      smell("nil_check") => "Cart#price checks for nil (cart.rb:12). Prefer a default, a null object, or polymorphism.",
      smell("repeated_conditional", count: 3) =>
        "Cart#price branches on the same test 3 times (cart.rb:12). Replace the scattered checks with polymorphism.",
      smell("state_sprawl", count: 5) =>
        "Cart#price holds 5 instance variables (cart.rb:12). " \
        "Split the class, or gather related fields into value objects."
    }
  end

  it "names the method a smell sits in, where it is, and what to do about it" do
    smells.each { |finding, said| expect(message(finding)).to(eq(said)) }
  end

  def effort
    Hashira::Complexity::MethodFinding::Effort.new(cognitive: 10, calls: 12, site: "shop.rb:4", dominant: "elsif")
  end

  it "names the site of a complex method, and the advice its dominant construct earns" do
    finding = Hashira::Analysis::Finding.new(kind: "complexity", package: "Shop#total", evidence: [], detail: effort)
    expect(message(finding)).to(
      eq("Shop#total — cognitive 10, 12 calls (shop.rb:4). #{described_class::COMPLEXITY_ADVICE["elsif"]}")
    )
  end

  def clone(kind, hot:)
    overlap = Hashira::Duplication::DuplicationFinding::Overlap.new(size: 3, mass: 45, kind:, hot:)
    Hashira::Analysis::Finding.new(kind: "duplication", package: "a.rb:1", evidence: [], detail: overlap)
  end

  it "says how a clone family varies" do
    expect(message(clone(:literal, hot: false))).to(
      eq("3 similar fragments (mass 45) — differs only in literal values — extract a method, pass them as arguments.")
    )
  end

  it "warns when both sites of a clone churn" do
    expect(message(clone(:identical, hot: true))).to(
      end_with("call it from each site. Both sites change often — fix one, miss the other.")
    )
  end
end
