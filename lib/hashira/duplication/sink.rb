# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Sink
  LEVELS = %i[debug info warn error fatal unknown].freeze

  LOGGER = /(?:\A|[_.@])log(?:ger)?\z/

  def initialize(node, rescued = nil)
    @node = node
    @rescued = rescued
  end

  def sink? = @node.is_a?(Prism::CallNode) && (logged? || reported?)

  def message = strings.flat_map { walk(it).drop(1) }

  private

  def logged? = LEVELS.include?(@node.name) && LOGGER.match?(@node.receiver&.slice.to_s)

  def reported? = Array(@node.arguments&.arguments).any? { handed?(it) }

  def handed?(node) = node.is_a?(Prism::LocalVariableReadNode) && node.name == @rescued

  def strings = walk(@node).grep(Prism::InterpolatedStringNode)

  def walk(node) = Hashira::Analysis::NodeWalk.new(node).collect
end
