# frozen_string_literal: true

module Hashira::Report::Phrases
  COMPLEXITY_ADVICE = {
    "if" => "flatten the branching — guard clauses, early returns, or polymorphism.",
    "elsif" => "replace the elsif ladder with a lookup or polymorphic dispatch.",
    "else" => "flatten the branching — guard clauses, early returns, or polymorphism.",
    "case" => "a case this size often wants polymorphism or a dispatch table.",
    "boolean" => "name the compound condition in a predicate method.",
    "rescue" => "narrow the rescue, or lift error handling to the caller.",
    "while" => "extract the loop body into its own method.",
    "until" => "extract the loop body into its own method.",
    "for" => "extract the loop body into its own method.",
    "unless" => "invert to a guard clause or a named predicate.",
    "ternary" => "extract the nested ternary into a named method."
  }.freeze

  DUPLICATION_ADVICE = {
    identical: "byte-for-byte identical — extract a shared method and call it from each site.",
    literal: "differs only in literal values — extract a method, pass them as arguments.",
    message: "differs only in the receiver or message — extract a method taking the receiver.",
    constant: "differs only in a constant — extract a method and parameterize it.",
    structure: "the control flow differs — extract the common core, but verify by hand (lower confidence).",
    mixed: "extract the shared shape and pass what differs as parameters."
  }.freeze

  module_function

  def message(finding) = public_send("on_#{finding.kind}", finding)

  def on_cycle(finding)
    detail = finding.detail
    from, to = detail[:weak]
    weight = detail[:weight]
    "#{finding.package} can reach itself: #{finding.cycle.join(" -> ")} — any change may ripple back " \
      "around. The lightest edge on this cycle is #{from} -> #{to} (#{weight} ref#{"s" unless weight == 1})."
  end

  def on_sdp_violation(finding)
    detail = finding.detail
    from, to = detail.values_at(:from, :to)
    "#{from} (I=#{score(detail[:from_instability])}) depends on the LESS stable #{to} " \
      "(I=#{score(detail[:to_instability])}) — churn in #{to} will force churn in #{from}. " \
      "Invert the edge or extract the stable part of #{to} that #{from} needs."
  end

  def on_mixed_audience(finding)
    package = finding.package
    parts = finding.detail[:parts]
    "#{package} splits #{parts.size} ways: #{parts.map { clause(it) }.join("; ")} — " \
      "parts with separate client bases are separate packages in disguise. " \
      "Split #{package} along that seam#{addendum(parts)}."
  end

  def on_wide_edge(finding)
    detail = finding.detail
    from, to = detail.values_at(:from, :to)
    names = detail[:constants]
    "#{from} -> #{to} is #{names.size} constants wide (#{names.join(", ")}) — " \
      "every one is a reason for #{from} to change. Front #{to} with one facade."
  end

  def on_roll_call(finding)
    detail = finding.detail
    "the words #{detail[:words].join(", ")} are listed together in #{detail[:files].join(", ")} — " \
      "#{detail[:packages].size} packages keep one roll-call in sync by hand. " \
      "Make the list data with a single owner."
  end

  def on_complexity(finding)
    detail = finding.detail
    "#{finding.package} — cognitive #{detail[:cognitive]}, #{detail[:calls]} calls " \
      "(#{detail[:site]}). #{COMPLEXITY_ADVICE.fetch(detail[:dominant])}"
  end

  def on_duplication(finding)
    detail = finding.detail
    "#{detail[:size]} similar fragments (mass #{detail[:mass]}) — " \
      "#{DUPLICATION_ADVICE.fetch(detail[:kind])}#{footnote(detail)}"
  end

  def score(value) = format("%.2f", value)

  def count(number, noun) = "#{number} #{number == 1 ? noun : "#{noun}s"}"

  def clause(part) = "#{part[:users].join(", ")} #{verb(part)} #{part[:constants].join(", ")}"

  def verb(part)
    return "share" if part[:shared]
    part[:users].size == 1 ? "alone uses" : "use"
  end

  def addendum(parts)
    parts.any? { it[:shared] } ? ", keeping the shared constants as the base layer the rest builds on" : ""
  end

  def footnote(detail)
    detail[:hot] ? " Both sites change often — fix one, miss the other." : ""
  end
end
