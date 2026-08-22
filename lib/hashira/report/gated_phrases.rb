# frozen_string_literal: true

module Hashira::Report::Phrases
  ADVICE = {
    "abstract_stub_gap" => "Implement it, or drop the stub that promises it.",
    "dead_method" => "Delete it, or call it.",
    "hierarchy_dispatch" => "Put the behaviour on the class, and let dispatch do the asking."
  }.merge(
    "mixin_collision" => "Name them apart, or let the class settle it.",
    "override_arity_mismatch" => "Match the signature, or give the override its own name.",
    "private_override" => "A caller holding the base contract gets NoMethodError. Keep the visibility, or rename it."
  ).merge(
    "registry_gap" => "Define the handler, or drop the entry the table cannot reach.",
    "unanswered_message" => "Fix the name, or define the method.",
    "unchained_initialize" => "Call super, or assign them here.",
    "unreachable_rescue" => "Drop the handler, or raise what it was written for."
  ).freeze

  module_function

  def on_abstract_stub_gap(finding)
    verdict(finding, "never implements #{names(finding)}, which #{owners(finding)} leaves to it")
  end

  def on_dead_method(finding)
    verdict(finding, "is #{marked(finding)}, and nothing in #{owners(finding)} or below it ever names it")
  end

  def on_mixin_collision(finding)
    verdict(finding, "takes #{names(finding)} from both #{owners(finding)}, and the last include silently wins")
  end

  def on_private_override(finding)
    verdict(finding, "is #{marked(finding)} here, but #{owners(finding)} makes it public")
  end

  def on_registry_gap(finding)
    verdict(finding, "routes to #{names(finding)}, which #{owners(finding)} cannot answer")
  end

  def on_unanswered_message(finding)
    verdict(finding, "calls #{names(finding)} on itself, and nothing #{owners(finding)} can reach defines it")
  end

  def on_unchained_initialize(finding)
    verdict(finding, "leaves #{names(finding)} nil, because it builds without the super #{owners(finding)} needs")
  end

  def on_hierarchy_dispatch(finding)
    verdict(finding, "asks whether something is #{names(finding)}, a class in its own family")
  end

  def on_override_arity_mismatch(finding)
    verdict(finding, "cannot take the calls #{owners(finding)} accepts")
  end

  def on_unreachable_rescue(finding)
    verdict(finding, "rescues #{names(finding)}, which nothing in the project raises")
  end

  def verdict(finding, clause) = "#{finding.package} #{clause} (#{sited(finding)}). #{ADVICE.fetch(finding.kind)}"

  def sited(finding) = finding.detail[:site]

  def names(finding) = quoted(finding.detail[:names])

  def owners(finding) = finding.detail[:owners].join(", ")

  def marked(finding) = finding.detail[:section]
end
