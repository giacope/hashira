# frozen_string_literal: true

class Hashira::Report::Phrases
  CONCRETE = "Extract what they share into an abstract base both extend, or compose instead."

  REFUSED = "Compose the parent instead of extending it, or move the refused methods to the subclasses that want them."

  COHESION = "Split the class along that seam."

  DATA_CLASS = "Move the code that works on these fields into the class, or declare it a Data value."

  MIDDLE_MAN = "Let callers talk to the delegate directly, or give the class work of its own."

  private

  def count(number, noun) = Hashira::Report::Count.new(number, noun).to_s

  def on_concrete_inheritance(finding)
    detail = finding.detail
    places = detail[:places]
    parent = detail[:parent]
    return plain(finding, "inherits from #{parent}, a concrete class the project also builds", CONCRETE) unless places
    extended = places == 1 ? "a subclass extends" : "#{places} subclasses extend"
    plain(finding, "is a concrete class the project also builds, and #{extended} it", CONCRETE)
  end

  def on_refused_bequest(finding)
    detail = finding.detail
    places = detail[:places]
    return plain(finding, "is overridden by #{refusers(places)} only to raise or do nothing", REFUSED) if places
    names = detail[:refusals].map(&:name)
    plain(finding, "overrides #{quoted(names)} of #{detail[:parent]} only to raise or do nothing", REFUSED)
  end

  def refusers(places) = places == 1 ? "a subclass" : "#{places} subclasses"

  def on_low_cohesion(finding)
    plain(finding, "splits into #{finding.detail[:count]} groups of methods that share no state", COHESION)
  end

  def on_message_chain(finding)
    near, far = finding.detail[:through]
    advice = "Ask #{near} for what you need, or hand the #{far} in."
    plain(finding, "#{reaching(finding.detail[:places])} #{near} into #{far}", advice)
  end

  def reaching(places) = places ? "— #{count(places, "method")} reach#{"es" if places == 1} through" : "reaches through"

  def on_data_class(finding)
    plain(finding, "holds #{quoted(finding.detail[:fields])} and does nothing else", DATA_CLASS)
  end

  def on_middle_man(finding)
    detail = finding.detail
    "#{finding.package} forwards #{detail.count} of its #{detail.total} public methods to #{detail.delegate} " \
      "(#{detail.site}). #{MIDDLE_MAN}"
  end
end
