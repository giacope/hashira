# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Routine
  SUPERS = [Prism::SuperNode, Prism::ForwardingSuperNode].freeze

  HIDDEN = %i[private protected].freeze

  def initialize(label, owner, node, section)
    @label = label
    @owner = owner
    @node = node
    @section = section
  end

  def to_a = [@owner, sign, selector]

  def place = @label.place

  def finding(kind) = @label.finding(kind, :method)

  def dead?(spoken, anchors, exposure, framing)
    used = overrides? || spoken.called?(selector) || @label.rooted?(anchors, exposed? && exposure.exposed?(@owner))
    !used && !framing.framed?(self) && !framing.open?(@owner)
  end

  def hooked?(hosting)
    hosting.patched?(@owner) || (exposed? ? hosting.hosted?(@owner) : hosting.backed?(@owner))
  end

  private

  def selector = @node.name.to_s

  def sign = @label.to_s.delete_suffix(selector).chars.fetch(-1)

  def exposed? = !@node.receiver.nil? || !HIDDEN.include?(@section)

  def overrides? = Hashira::Analysis::NodeWalk.new(@node).collect.any? { SUPERS.include?(it.class) }
end
