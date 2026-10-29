# frozen_string_literal: true

class Hashira::Complexity::MethodFinding
  KIND = "complexity"

  class Effort
    FLATTEN = "flatten the branching — guard clauses, early returns, or polymorphism."

    LOOP_BODY = "extract the loop body into its own method."

    ADVICE = {
      "if" => FLATTEN, "else" => FLATTEN,
      "elsif" => "replace the elsif ladder with a lookup or polymorphic dispatch."
    }.merge(
      "case" => "a case this size often wants polymorphism or a dispatch table.",
      "boolean" => "name the compound condition in a predicate method.",
      "rescue" => "narrow the rescue, or lift error handling to the caller."
    ).merge(
      "while" => LOOP_BODY, "until" => LOOP_BODY, "for" => LOOP_BODY
    ).merge(
      "unless" => "invert to a guard clause or a named predicate.",
      "ternary" => "extract the nested ternary into a named method.",
      "recursion" => "a recursion is a loop the reader unwinds by hand; name the traversal or make it iterative."
    ).freeze

    private_constant :FLATTEN, :LOOP_BODY, :ADVICE

    def initialize(cognitive:, calls:, site:, dominant:)
      @cognitive = cognitive
      @calls = calls
      @site = site
      @dominant = dominant
    end

    def to_h = { cognitive: @cognitive, calls: @calls, site: @site, dominant: @dominant }

    def phrase(package) = "#{package} — cognitive #{@cognitive}, #{@calls} calls (#{@site}). #{ADVICE.fetch(@dominant)}"
  end

  def initialize(subject, site, charges)
    @subject = subject
    @site = site
    @charges = charges
  end

  def to_finding
    proof = Hashira::Analysis::Finding::Proof.new(@charges.evidence, [@site])
    Hashira::Analysis::Finding.new(KIND, Hashira::Analysis::Finding::Name.new(@subject), detail, proof)
  end

  private

  def detail = Effort.new(cognitive: @charges.total, calls: @charges.count, site: @site, dominant: @charges.dominant)
end
