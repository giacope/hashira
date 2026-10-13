# frozen_string_literal: true

require "prism"

class Hashira::Complexity::InlinedScore < Hashira::Complexity::CognitiveScore
  SELVES = [NilClass, Prism::SelfNode].freeze

  def initialize(node, helpers)
    super(node)
    @helpers = helpers
  end

  def inlined = visits.map(&:first)

  def depth = visits.map(&:last).max.to_i

  private

  def visits
    walked
    @_visits
  end

  def blank
    super
    @_visits = []
    @_hops = 0
  end

  def on_call(node)
    super
    helper = @helpers[node.name]
    enter(helper) if helper && SELVES.include?(node.receiver.class)
  end

  def enter(helper)
    @_hops += 1
    @_visits << [helper, @_hops]
    visit(helper.body)
    @_hops -= 1
  end
end
