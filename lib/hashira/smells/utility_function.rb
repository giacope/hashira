# frozen_string_literal: true

require "prism"

class Hashira::Smells::UtilityFunction < Hashira::Smells::Check
  PROTOCOL = { 0 => %i[hash inspect to_s], 1 => %i[== eql? equal? <=> === coerce] }.freeze

  ADVICE = "Move it onto the object it serves, or make it private."

  def initialize(subject, rules, refs)
    super(subject, rules)
    @refs = refs
  end

  private

  def smelly? = subject.home.class? && standing.public? && !standing.polymorphic? && !protocol? && calls? && stateless?

  def protocol? = PROTOCOL.fetch(signature.arity, []).include?(signature.name)

  def standing = subject.standing

  def signature = subject.accept(Hashira::Smells::Signature)

  def stateless? = @refs.ego.zero? && Hashira::Smells::Opaque.new(body).none?

  def detail = Hashira::Smells::Spot.new(site, "touches no instance state", ADVICE)

  def calls? = body.any?(Prism::CallNode)

  def body = @_body ||= subject.accept(Hashira::Smells::Scope).inside
end
