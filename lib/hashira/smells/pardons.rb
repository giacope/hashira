# frozen_string_literal: true

require "prism"

class Hashira::Smells::Pardons
  def initialize(subject, reach, sampling, readers = Hashira::Smells::Readers.new(subject))
    @subject = subject
    @reach = reach
    @sampling = sampling
    @readers = readers
  end

  def reachable?(nodes) = @reach.reachable?(nodes)

  def lesser?(nodes) = cheap?(nodes) || !reachable?(nodes.reject { preset?(it) })

  def excused?(nodes) = glance?(nodes) || @sampling.sampled?(nodes)

  private

  def cheap?(nodes) = Hashira::Smells::Lookup.new(nodes.first, @readers).cheap?

  def preset?(node) = presets.include?(node)

  def presets = @_presets ||= Set.new.compare_by_identity.merge(defaults)

  def defaults = [@subject.node.parameters].compact.flat_map { [it] + Hashira::Smells::Scope.new(it).inside }

  def glance?(nodes) = cheap?(nodes) && nodes.combination(3).none? { thrice?(it) }

  def thrice?(trio) = trio.combination(2).all? { reachable?(it) }
end
