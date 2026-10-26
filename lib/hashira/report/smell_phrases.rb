# frozen_string_literal: true

class Hashira::Report::Phrases
  NIL_ADVICE = "Prefer a default, a null object, or polymorphism."

  ABSENCE = "Absence is the answer here, so ask for it: exists? instead of fetching a record to test for nil."

  DATA_CLUMP = "Introduce a parameter object."

  SPRAWL = "Split the class, or gather related fields into value objects."

  REPEATED_CALL = "Name the result in a local variable."

  MANUAL_DISPATCH = "Trust the duck type, or split the callers into two adapters."

  SWITCH = "Move each branch onto the type or state it tests, and let polymorphism pick."

  MODULE_INITIALIZE =
    "A mixin that carries constructor state is implementation inheritance; compose a collaborator instead."

  STATEFUL_MIXIN = "Make it a decorator: wrap the host and reach it through its public methods."

  private

  def on_control_parameter(finding)
    detail = finding.detail
    "#{finding.package} is steered by #{quoted(detail[:names])} (#{detail[:site]}). " \
      "Split the method, or pass a strategy instead of a flag."
  end

  def on_data_clump(finding) = plain(finding, "passes the same parameters between methods", DATA_CLUMP)

  def on_repeated_call(finding)
    detail = finding.detail
    places = detail[:places]
    return plain(finding, "repeats identical calls", REPEATED_CALL) unless places
    plain(finding, "repeats #{count(detail[:calls], "call")} in #{count(places, "method")}", REPEATED_CALL)
  end

  def on_manual_dispatch(finding)
    via = finding.detail[:via]
    plain(finding, "dispatches manually via #{via.join(" and ")}", via == ["respond_to?"] ? MANUAL_DISPATCH : SWITCH)
  end

  def on_module_initialize(finding) = plain(finding, "defines initialize in a module", MODULE_INITIALIZE)

  def on_stateful_mixin(finding) = plain(finding, "mixes behavior into its host's own state", STATEFUL_MIXIN)

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
      "(#{detail[:site]}). The behavior may belong on #{alternatives(detail.fetch(:types, names))}."
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
    places = detail[:places]
    return "#{finding.package} checks for nil (#{detail[:site]}). #{remedy(detail[:origin])}" unless places
    "#{finding.package} may be nil, and #{count(places, "method")} check#{"s" if places == 1} for it " \
      "(#{detail[:site]}). #{NIL_ADVICE} Settle it where the nil is made."
  end

  def remedy(origin) = origin == :absence ? ABSENCE : NIL_ADVICE

  def on_repeated_conditional(finding)
    tally(finding, "branches on the same test %d times", "Replace the scattered checks with polymorphism.")
  end

  def on_state_sprawl(finding)
    detail = finding.detail.to_h
    "#{finding.package} holds #{detail[:count]} instance variables#{weighed(detail)} (#{detail[:site]}). #{SPRAWL}"
  end

  def weighed(detail) = (", weighing #{detail[:weight]}, more than #{detail[:limit]}" if detail[:weight])

  def on_utility_function(finding)
    detail = finding.detail
    "#{finding.package} touches no instance state (#{detail[:site]}). " \
      "Move it onto the object it serves, or make it private."
  end

  def tally(finding, event, advice)
    detail = finding.detail
    "#{finding.package} #{format(event, detail[:count])} (#{detail[:site]}). #{advice}"
  end

  def quoted(names) = names.map { "'#{it}'" }.join(", ")

  def alternatives(names) = [names[0..-2].join(", "), names.last].reject(&:empty?).join(" or ")
end
