# frozen_string_literal: true

module Hashira::Report::Phrases
  CHANGE_ADVICE = {
    true => "and one refers to the other — every change crosses the package boundary. " \
      "Narrow what one asks of the other, or move them into one package.",
    false => "though neither refers to the other — the coupling is hidden. " \
      "Name what they share in one place both can depend on."
  }.freeze

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

  def guarded(edges)
    held = edges.select { it[:guarantees] }
    return "" if held.empty?
    " #{holders(held)} a dependent: option (#{pledge(held)}) — cutting #{held.one? ? "it" : "one"} drops what " \
      "deleting the owner does to its records, so hand that to an object above both packages first."
  end

  def holders(held) = held.one? ? "#{arrow(held.first)} carries" : "#{held.size} of these edges carry"

  def pledge(held)
    edge = held.first
    site, said = edge[:guarantees].first.split(": ", 2)
    lead = "#{arrow(edge)}: " unless held.one?
    "#{lead}#{said} at #{site}#{", …" if held.sum { it[:guarantees].size } > 1}"
  end

  def arrow(edge) = "#{edge[:from]} -> #{edge[:to]}"

  def on_bidirectional_association(finding)
    detail = finding.detail
    parent, children = detail.values_at(:parent, :children)
    return paired(finding, parent, children.first) if children.one?
    "#{parent} is navigated both ways by #{children.size} models, #{children.join(", ")}: each declares an " \
      "association to the other (#{finding.anchors.first}), which ties them together. Drop #{parent}'s side of each " \
      "and query the model where it is needed.#{carried(detail)}"
  end

  def paired(finding, parent, child)
    "#{parent} and #{child} each declare an association to the other (#{finding.anchors.first}) — navigating both " \
      "ways ties them together. Drop #{parent}'s side and query #{child} where it is needed.#{carried(finding.detail)}"
  end

  def carried(detail)
    pledged = detail[:guarantees]
    return "" if pledged.empty?
    " It carries #{pledged.map { it.split(": ", 2).last }.join("; ")}: hand that to an object above both, or to the " \
      "foreign key, first."
  end

  def on_dead_code(finding)
    detail = finding.detail
    verb = detail[:noun] == :method ? "called" : "referred to"
    "#{finding.package} is never #{verb} in the project (#{detail[:site]}). " \
      "Delete it, or name it in dead_code roots if code outside the project uses it."
  end

  def on_change_coupling(finding)
    detail = finding.detail
    first, second = detail.files.zip(detail.packages).map { |file, package| "#{file} (#{package})" }
    "#{first} and #{second} changed together in #{detail.shared} commits, #{detail.degree}% of their changes, " \
      "#{CHANGE_ADVICE.fetch(detail.explicit)}"
  end

  def leaning(detail)
    order = detail.leaning
    return "" unless order
    against = detail.against
    left = against.zero? ? "no ref" : "only #{count(against, "ref")}"
    " The code leans another way: layered #{order.join(", ")}, #{left} would point outward — check the declared order."
  end
end
