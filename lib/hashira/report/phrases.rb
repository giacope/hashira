# frozen_string_literal: true

module Hashira::Report::Phrases
  FLATTEN = "flatten the branching — guard clauses, early returns, or polymorphism."

  LOOP_BODY = "extract the loop body into its own method."

  COMPLEXITY_ADVICE = {
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
    "ternary" => "extract the nested ternary into a named method."
  ).freeze

  ROSTER = 6

  module_function

  def message(finding) = public_send("on_#{finding.kind}", finding)

  def on_cycle(finding)
    detail = finding.detail
    "#{roster(detail[:members])} depend on each other in a cycle#{joined(detail[:folded])} — " \
      "any change may ripple back around. " \
      "The cheapest cut is #{detail[:cut].map { link(it) }.join(", ")}."
  end

  def roster(members)
    shown = members.first(ROSTER)
    rest = members.size - shown.size
    rest.positive? ? "#{shown.join(", ")} and #{rest} more" : "#{shown[..-2].join(", ")} and #{shown.last}"
  end

  def joined(folded)
    return "" if folded.empty?
    " (#{folded.one? ? "#{folded.first} is" : "#{roster(folded)} are"} in it only through folded types)"
  end

  def link(edge)
    weight = edge[:weight]
    "#{edge[:from]} -> #{edge[:to]} (#{weight} ref#{"s" unless weight == 1})"
  end

  def on_sdp_violation(finding)
    detail = finding.detail
    from, to = detail.deconstruct
    "#{from} (I=#{score(detail.from_instability)}) depends on the LESS stable #{to} " \
      "(I=#{score(detail.to_instability)}) — churn in #{to} will force churn in #{from}. " \
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
    "#{finding.package} — cognitive #{detail.cognitive}, #{detail.calls} calls " \
      "(#{detail.site}). #{COMPLEXITY_ADVICE.fetch(detail.dominant)}"
  end

  def score(value) = format("%.2f", value)

  def count(number, noun) = "#{number} #{number == 1 ? noun : "#{noun}s"}"

  def withheld(rest) = "  … and #{rest} more — raise the cap with --top, or read them all with --json"

  def clause(part) = "#{part[:users].join(", ")} #{verb(part)} #{part[:constants].join(", ")}"

  def verb(part)
    return "share" if part[:shared]
    part[:users].size == 1 ? "alone uses" : "use"
  end

  def addendum(parts)
    parts.any? { it[:shared] } ? ", keeping the shared constants as the base layer the rest builds on" : ""
  end
end
