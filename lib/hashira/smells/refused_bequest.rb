# frozen_string_literal: true

class Hashira::Smells::RefusedBequest < Hashira::Smells::Check
  VERBS = { raise: "raises", nothing: "does nothing" }.freeze

  Refused = Data.define(:bequest, :name, :home, :verb, :site)

  private

  def smelly? = refused.any?

  def family = subject.family

  def name = subject.subject

  def refused = @_refused ||= family.definitions(name).select { refuses?(it) }

  def refuses?(method)
    granted = bequest[method.node.name]
    granted && refusal(method) && !refusal(granted)
  end

  def refusal(method) = Hashira::Smells::Refusal.new(method.node).of

  def bequest
    @_bequest ||= family.ancestors(name).reverse.flat_map { family.definitions(it) }.to_h { [it.node.name, it] }
  end

  def detail = { site:, parent: family.parent(name), refusals: }

  def refusals
    refused.map do |method|
      named = method.node.name
      granted = bequest[named]
      Refused.new(bequest: granted.subject, name: named.to_s, home: granted.site, verb: verb(method), site: method.site)
    end
  end

  def verb(method) = VERBS.fetch(refusal(method))

  def evidence
    refused.map do |method|
      named = method.node.name
      "#{named} #{verb(method)} (line #{method.line}, over #{bequest[named].owner})"
    end
  end
end
