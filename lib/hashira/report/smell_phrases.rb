# frozen_string_literal: true

module Hashira::Report::Phrases
  NIL_ADVICE = {
    nil => "Prefer a default, a null object, or polymorphism.",
    outside: "The value comes from outside; translate the missing value where it enters, at the boundary.",
    both: "Translate a value missing from outside where it enters; elsewhere prefer a null object or polymorphism."
  }.freeze

  UTILITY_ADVICE = { module: "make it a module function", class: "make it private" }.freeze

  DATA_CLUMP = "Introduce a parameter object."

  REPEATED_CALL = "Name the result in a local variable."

  MANUAL_DISPATCH = "Trust the duck type, or split the callers into two adapters."

  MODULE_INITIALIZE =
    "A mixin that carries constructor state is implementation inheritance; compose a collaborator instead."

  module_function

  def on_control_parameter(finding)
    detail = finding.detail
    "#{finding.package} is steered by #{quoted(detail[:names])} (#{detail[:site]}). " \
      "Split the method, or pass a strategy instead of a flag."
  end

  def on_data_clump(finding) = plain(finding, "passes the same parameters between methods", DATA_CLUMP)

  def on_repeated_call(finding) = plain(finding, "repeats identical calls", REPEATED_CALL)

  def on_manual_dispatch(finding) = plain(finding, "dispatches manually via respond_to?", MANUAL_DISPATCH)

  def on_module_initialize(finding) = plain(finding, "defines initialize in a module", MODULE_INITIALIZE)

  def plain(finding, said, advice) = "#{finding.package} #{said} (#{finding.detail[:site]}). #{advice}"

  def on_boundary_sprawl(finding)
    detail = finding.detail
    "#{detail[:count]} methods across #{detail[:files]} files each pick apart #{finding.package}'s " \
      "internals. Front the boundary with one adapter the rest can lean on."
  end

  def on_feature_envy(finding)
    detail = finding.detail.to_h
    names = detail[:names]
    "#{finding.package} refers to #{quoted(names)} more than to self, #{balance(names, detail)} " \
      "(#{detail[:site]}). The behavior may belong on #{names.one? ? names.first : "whichever of them it serves"}."
  end

  def balance(names, detail) = "#{detail[:count]}#{" each" unless names.one?} to #{detail[:ego]}"

  def on_assumed_state(finding)
    detail = finding.detail
    "#{finding.package} reads instance variables nothing in the class assigns (#{detail[:site]}). " \
      "#{[orphaned(detail[:unassigned]), installing(detail[:installed])].compact.join(" ")}"
  end

  def orphaned(names)
    return if names.empty?
    single = names.one?
    "Nothing ever assigns #{quoted(names)}, so #{single ? "it reads" : "they read"} nil: a typo or a dead hook. " \
      "Assign #{single ? "it" : "them"} where the object is built, or delete the read."
  end

  def installing(names)
    return if names.empty?
    "Its subclasses are expected to install #{quoted(names)}; pass #{names.one? ? "it" : "them"} in instead."
  end

  def on_nil_check(finding)
    detail = finding.detail
    "#{finding.package} checks for nil (#{detail[:site]}). #{NIL_ADVICE.fetch(detail[:origin])}"
  end

  def on_repeated_conditional(finding)
    tally(finding, "branches on the same test %d times", "Replace the scattered checks with polymorphism.")
  end

  def on_state_sprawl(finding)
    tally(finding, "holds %d instance variables", "Split the class, or gather related fields into value objects.")
  end

  def on_utility_function(finding)
    detail = finding.detail
    "#{finding.package} touches no instance state (#{detail[:site]}). " \
      "Move it onto the object it serves, or #{UTILITY_ADVICE.fetch(detail[:owner])}."
  end

  def tally(finding, event, advice)
    detail = finding.detail
    "#{finding.package} #{format(event, detail[:count])} (#{detail[:site]}). #{advice}"
  end

  def quoted(names) = names.map { "'#{it}'" }.join(", ")
end
