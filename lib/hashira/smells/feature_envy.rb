# frozen_string_literal: true

require "prism"

class Hashira::Smells::FeatureEnvy < Hashira::Smells::Check
  Envy = Data.define(:site, :names, :types, :count, :ego)

  private

  def smelly?
    !subject.singleton? && !subject.mixin? && !subject.polymorphic? && refs.ego.positive? && envied.any?
  end

  def refs = @_refs ||= Hashira::Smells::Refs.new(subject.node, subject.ownership.vocabulary)

  def envied = @_envied ||= refs.envious.select { type(it) }.reject { excused?(it) }

  def excused?(holder) = foreign.dismiss?(holder) || paired?(holder) || transit.passing?(holder)

  def type(holder) = foreign.kinds(holder).find { serves?(it, holder) }&.last

  def serves?(type, holder) = asked(holder, type).subset?(repertoire.of(type))

  def asked(holder, type)
    seen = repertoire.closed?(type) ? refs.sends(holder) : refs.reads(holder)
    seen.to_set { it.name.to_s.delete_suffix("=") }
  end

  def repertoire = subject.ownership.repertoire

  def transit = @_transit ||= Hashira::Smells::Transit.new(subject.node, refs)

  def paired?(holder) = partners(holder.scope) > 1

  def partners(scope) = scope.is_a?(Prism::BlockNode) ? refs.envious.count { it.scope == scope } : 0

  def foreign = @_foreign ||= Hashira::Smells::Foreign.new(subject, subject.ownership)

  def detail = Envy.new(site:, names: envied.map(&:name).uniq, types:, count:, ego: refs.ego)

  def count = refs.lines(envied.first).size

  def types = envied.map { type(it) }.uniq

  def evidence = (envied + [Hashira::Smells::Refs::SELF]).map { tally(it.name, refs.lines(it).uniq) }
end
