# frozen_string_literal: true

class Hashira::Smells::FeatureEnvy < Hashira::Smells::Check
  private

  def smelly?
    !subject.singleton? && !subject.mixin? && refs.ego.positive? && envied.any?
  end

  def refs = @refs ||= Hashira::Smells::Refs.new(subject.node)

  def envied = @envied ||= refs.envious

  def detail = { site:, names: envied }

  def evidence = envied.map { |name| tally(name, refs.lines(name).uniq) }
end
