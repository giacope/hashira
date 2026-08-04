# frozen_string_literal: true

require "prism"

class Hashira::Smells::DuplicateMethodCall < Hashira::Smells::Check
  LIMIT = 1

  private

  def smelly? = repeats.any?

  def calls = @calls ||= Hashira::Smells::Scope.inside(subject.node).grep(Prism::CallNode)

  def plain?(node)
    !node.receiver && !node.arguments && !node.block.is_a?(Prism::BlockArgumentNode)
  end

  def repeats
    @repeats ||= usual.reject { |_handle, nodes| whole.value?(nodes) }.merge(whole)
  end

  def usual
    calls.reject { plain?(it) || it.name == :new }
      .group_by { handle(it) }.select { |_handle, group| group.size > LIMIT }
  end

  def whole
    @whole ||=
      calls.select { it.block.is_a?(Prism::BlockNode) }
        .group_by { it.slice.gsub(/\s+/, " ") }.select { |_handle, group| group.size > LIMIT }
  end

  def handle(node) = "#{title(node)}#{signature(node)}"

  def title(node)
    [node.receiver&.slice, node.name].compact.join(node.safe_navigation? ? "&." : ".")
  end

  def signature(node)
    wrap(([node.arguments&.slice] + pass(node.block)).compact)
  end

  def pass(block) = block.is_a?(Prism::BlockArgumentNode) ? [block.slice] : []

  def wrap(parts) = parts.empty? ? "" : "(#{parts.join(", ")})"

  def evidence
    repeats.map { |handle, nodes| "#{handle} × #{nodes.size} (#{stamp(lines(nodes))})" }
  end

  def lines(nodes) = nodes.map { it.location.start_line }.uniq

  def stamp(lines) = "line#{"s" if lines.size > 1} #{lines.join(", ")}"
end
