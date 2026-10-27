# frozen_string_literal: true

class Hashira::Report::Phrases
  CONCRETE = "Extract what they share into an abstract base both extend, or compose instead."

  REFUSED = "Compose the parent instead of extending it, or move the refused methods to the subclasses that want them."

  COHESION = "Split the class along that seam."

  DATA_CLASS = "Move the code that works on these fields into the class."

  BAGGED = "Move that code into the class, so the data and what it means live together."

  MIDDLE_MAN = "Let callers talk to the delegate directly, or give the class work of its own."

  private

  def count(number, noun) = Hashira::Report::Count.new(number, noun).to_s

  def on_concrete_inheritance(finding)
    detail = finding.detail.to_h
    places = detail[:places]
    mode = detail[:mode]
    return cored(finding, detail[:parent]) if mode == :core
    return plain(finding, inherits(detail), CONCRETE) unless places
    if mode == :overriding
      return plain(finding, "is a concrete class, and #{overriders(places)} its working methods", CONCRETE)
    end
    extended = places == 1 ? "a subclass extends" : "#{places} subclasses extend"
    plain(finding, "is a concrete class the project also builds, and #{extended} it", CONCRETE)
  end

  def inherits(detail)
    parent = detail[:parent]
    return "overrides working methods of #{parent}, a concrete class" if detail[:mode] == :overriding
    "inherits from #{parent}, a concrete class the project also builds"
  end

  def overriders(places) = "#{refusers(places)} override#{"s" if places == 1}"

  def cored(finding, parent)
    advice = "Keep one in a field and give the class methods of its own: what it inherits (map, select, merge) " \
      "answers a plain #{parent}, not this class."
    plain(finding, "extends #{parent}, a concrete core class", advice)
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
    detail = finding.detail
    users = detail[:users]
    said = "holds #{quoted(detail[:fields])} and does nothing else"
    return plain(finding, said, DATA_CLASS) unless users
    plain(finding, "#{said}, while #{count(users, "method")} elsewhere compute#{"s" if users == 1} with them", BAGGED)
  end

  def on_middle_man(finding)
    detail = finding.detail
    "#{finding.package} forwards #{detail.count} of its #{detail.total} public methods to #{detail.delegate} " \
      "(#{detail.site}). #{MIDDLE_MAN}"
  end
end
