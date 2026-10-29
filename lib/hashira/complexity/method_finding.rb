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

  def initialize(score)
    @score = score
  end

  def to_finding
    name = Hashira::Analysis::Finding::Name.new(@score.subject)
    Hashira::Analysis::Finding.new(KIND, name, detail, Hashira::Analysis::Finding::Proof.new(evidence, [site]))
  end

  private

  def detail
    Effort.new(cognitive: @score.cognitive, calls: @score.calls, site:, dominant:)
  end

  def site = "#{@score.file}:#{@score.line}"

  def evidence
    @score.increments.group_by(&:label).map do |label, increments|
      lines = increments.map(&:line).uniq
      "#{label} +#{increments.sum(&:cost)} (line#{"s" if lines.size > 1} #{lines.join(", ")})"
    end
  end

  def dominant
    @score.increments.group_by(&:label).transform_values { it.sum(&:cost) }.max_by(&:last).fetch(0)
  end
end
