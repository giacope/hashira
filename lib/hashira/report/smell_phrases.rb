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

  def on_boundary_sprawl(finding)
    detail = finding.detail
    "#{detail[:count]} methods across #{detail[:files]} files each pick apart #{finding.package}'s " \
      "internals. Front the boundary with one adapter the rest can lean on."
  end

  def on_feature_envy(finding)
    detail = finding.detail
    names = detail[:names]
    "#{finding.package} refers to #{quoted(names)} more than to self (#{detail[:site]}). " \
      "The behavior may belong on #{names.first}."
  end

  def on_instance_variable_assumption(finding)
    "#{finding.package} reads instance variables nothing in the class assigns (#{finding.detail[:site]}). " \
      "Assign them where the object is built, or pass the data explicitly."
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

  def on_abstract_stub_gap(finding)
    charged(finding, "never implements %s, which %s leaves to it", "Implement it, or drop the stub that promises it.")
  end

  def on_dead_method(finding)
    detail = finding.detail
    "#{finding.package} is #{detail[:section]}, and nothing in #{owners(detail)} or below it ever names it " \
      "(#{detail[:site]}). Delete it, or call it."
  end

  def on_mixin_collision(finding)
    detail = finding.detail
    "#{owners(detail)} each define #{quoted(detail[:names])} into #{finding.package} (#{detail[:site]}), " \
      "and the last include silently wins. Name them apart, or let the class settle it."
  end

  def on_unchained_initialize(finding)
    charged(finding, "leaves %s nil, because it builds without the super %s needs", "Call super, or assign them here.")
  end

  def on_override_arity_mismatch(finding)
    detail = finding.detail
    "#{finding.package} cannot take the calls #{owners(detail)} accepts (#{detail[:site]}). " \
      "Match the signature, or give the override its own name."
  end

  def on_private_override(finding)
    detail = finding.detail
    "#{finding.package} is #{detail[:section]} here, but #{owners(detail)} makes it public (#{detail[:site]}). " \
      "A caller holding the base contract gets NoMethodError. Keep the visibility, or give it another name."
  end

  def on_registry_gap(finding)
    detail = finding.detail
    "#{finding.package} routes to #{quoted(detail[:names])}, which #{detail[:owner]} cannot answer " \
      "(#{detail[:site]}). Define the handler, or drop the entry the table cannot reach."
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

  def charged(finding, event, advice)
    detail = finding.detail
    "#{finding.package} #{format(event, quoted(detail[:names]), owners(detail))} (#{detail[:site]}). #{advice}"
  end

  def tally(finding, event, advice)
    detail = finding.detail
    "#{finding.package} #{format(event, detail[:count])} (#{detail[:site]}). #{advice}"
  end

  def owners(detail) = detail[:owners].join(", ")

  def quoted(names) = names.map { "'#{it}'" }.join(", ")
end
