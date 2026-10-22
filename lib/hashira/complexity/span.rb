# frozen_string_literal: true

class Hashira::Complexity::Span
  HEREDOC = "<<"

  def initialize(node, notes)
    @node = node
    @notes = notes
  end

  def size = (@node.location.start_line..last).count { @notes.code?(it) }

  private

  def last = Hashira::Analysis::NodeWalk.new(@node).collect.map { ending(it) }.max

  def ending(node) = heredoc?(node) ? node.closing_loc.start_line : node.location.end_line

  def heredoc?(node) = node.respond_to?(:opening_loc) && node.opening_loc&.slice&.start_with?(HEREDOC)
end
