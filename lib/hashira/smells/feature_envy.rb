# frozen_string_literal: true

class Hashira::Smells::FeatureEnvy < Hashira::Smells::Check
  private

  def smelly?
    !subject.singleton? && !subject.mixin? && refs.ego.positive? && envied.any?
  end

  def refs = @_refs ||= Hashira::Smells::Refs.new(subject.node)

  def envied = @_envied ||= refs.envious.reject { foreign.dismiss?(it) }

  def foreign = @_foreign ||= Hashira::Smells::Foreign.new(subject, subject.ownership)

  def detail = { site:, names: envied }

  def evidence = envied.map { |name| tally(name, refs.lines(name).uniq) }
end
