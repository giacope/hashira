# frozen_string_literal: true

require "prism"

class Hashira::Smells::Pardons
  def initialize(subject, reach, sampling, readers)
    @subject = subject
    @reach = reach
    @sampling = sampling
    @readers = readers
  end

  def reachable?(nodes) = @reach.reachable?(nodes)

  def lesser?(nodes) = cheap?(nodes) || !reachable?(nodes.reject { presets.include?(it) })

  def excused?(nodes) = glance?(nodes) || @sampling.sampled?(nodes)

  private

  def cheap?(nodes) = Hashira::Smells::Lookup.new(nodes.first, @readers).cheap?

  def presets = @_presets ||= Set.new.compare_by_identity.merge(@subject.accept(Hashira::Smells::Defaults).to_a)

  def glance?(nodes) = cheap?(nodes) && nodes.combination(3).none? { thrice?(it) }

  def thrice?(trio) = trio.combination(2).all? { reachable?(it) }
end
