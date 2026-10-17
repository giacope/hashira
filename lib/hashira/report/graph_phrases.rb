# frozen_string_literal: true

module Hashira::Report::Phrases
  module_function

  def on_layer_violation(finding)
    detail = finding.detail
    "#{detail.inner} depends on #{detail.outer}, an outer layer, through #{count(detail.refs, "ref")} — " \
      "a layer may depend only on the layers declared inside it. Cut #{outward(detail.cut)}.#{leaning(detail)}"
  end

  def outward(edges)
    shown = edges.first(ROSTER).map { link(it) }
    rest = edges.size - shown.size
    listed = rest.positive? ? [*shown, count(rest, "more edge")] : shown
    [listed[..-2].join(", "), listed.last].reject(&:empty?).join(" and ")
  end

  def leaning(detail)
    order = detail.leaning
    return "" unless order
    against = detail.against
    left = against.zero? ? "no ref" : "only #{count(against, "ref")}"
    " The code leans another way: layered #{order.join(", ")}, #{left} would point outward — check the declared order."
  end
end
