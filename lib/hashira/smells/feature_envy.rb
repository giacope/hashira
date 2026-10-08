# frozen_string_literal: true

require "prism"

class Hashira::Smells::FeatureEnvy < Hashira::Smells::Check
  Envy = Data.define(:site, :names, :count, :ego)

  private

  def smelly?
    !subject.singleton? && !subject.mixin? && refs.ego.positive? && envied.any?
  end

  def refs = @_refs ||= Hashira::Smells::Refs.new(subject.node, subject.ownership.vocabulary)

  def envied = @_envied ||= refs.envious.reject { foreign.dismiss?(it) || paired?(it) || transit.passing?(it) }

  def transit = @_transit ||= Hashira::Smells::Transit.new(subject.node, refs)

  def paired?(holder) = partners(holder.scope) > 1

  def partners(scope) = scope.is_a?(Prism::BlockNode) ? refs.envious.count { it.scope == scope } : 0

  def foreign = @_foreign ||= Hashira::Smells::Foreign.new(subject, subject.ownership)

  def detail = Envy.new(site:, names: envied.map(&:name).uniq, count: refs.lines(envied.first).size, ego: refs.ego)

  def evidence = (envied + [Hashira::Smells::Refs::SELF]).map { tally(it.name, refs.lines(it).uniq) }
end
