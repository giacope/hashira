# frozen_string_literal: true

module Hashira::Report::Phrases
  module_function

  def on_control_parameter(finding)
    detail = finding.detail
    "#{finding.package} is steered by #{quoted(detail[:names])} (#{detail[:site]}). " \
      "Split the method, or pass a strategy instead of a flag."
  end

  def on_data_clump(finding)
    "#{finding.package} passes the same parameters between methods (#{finding.detail[:site]}). " \
      "Introduce a parameter object."
  end

  def on_duplicate_method_call(finding)
    "#{finding.package} repeats identical calls (#{finding.detail[:site]}). " \
      "Name the result in a local variable."
  end

  def on_feature_envy(finding)
    detail = finding.detail
    names = detail[:names]
    "#{finding.package} refers to #{quoted(names)} more than to self (#{detail[:site]}). " \
      "The behavior may belong on #{names.first}."
  end

  def on_instance_variable_assumption(finding)
    "#{finding.package} reads instance variables never set in initialize (#{finding.detail[:site]}). " \
      "Assign them in initialize, or pass the data explicitly."
  end

  def on_manual_dispatch(finding)
    "#{finding.package} dispatches manually via respond_to? (#{finding.detail[:site]}). " \
      "Trust the duck type, or split the callers into two adapters."
  end

  def on_module_initialize(finding)
    "#{finding.package} defines initialize in a module (#{finding.detail[:site]}). " \
      "Move construction into the including class."
  end

  def on_nil_check(finding)
    "#{finding.package} checks for nil (#{finding.detail[:site]}). " \
      "Prefer a default, a null object, or polymorphism."
  end

  def on_repeated_conditional(finding)
    tally(finding, "branches on the same test %d times", "Replace the scattered checks with polymorphism.")
  end

  def on_too_many_instance_variables(finding)
    tally(finding, "holds %d instance variables", "Split the class, or gather related fields into value objects.")
  end

  def on_utility_function(finding)
    "#{finding.package} touches no instance state (#{finding.detail[:site]}). " \
      "Move it onto the object it serves, or make it a module function."
  end

  def tally(finding, event, advice)
    detail = finding.detail
    "#{finding.package} #{format(event, detail[:count])} (#{detail[:site]}). #{advice}"
  end

  def quoted(names) = names.map { "'#{it}'" }.join(", ")
end
