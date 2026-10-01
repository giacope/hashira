# frozen_string_literal: true

require "prism"

class Hashira::Smells::RepeatedCall < Hashira::Smells::Check
  MINTS = %i[new dup clone allocate rand srand].freeze

  SOURCES = %w[SecureRandom Random].freeze

  LITERALS = [
    Prism::StringNode, Prism::SymbolNode, Prism::ArrayNode, Prism::HashNode,
    Prism::IntegerNode, Prism::FloatNode, Prism::RegularExpressionNode
  ].freeze

  private

  def smelly? = repeats.any?

  def calls
    @_calls ||= Hashira::Smells::Scope.inside(subject.node).grep(Prism::CallNode).reject { commanded?(it) || fresh?(it) }
  end

  def commanded?(node) = discards.include?(node)

  def discards = @_discards ||= Hashira::Smells::Discards.new(subject.node)

  def fresh?(node) = minted?(node) || fed(node).any? { minted?(it) }

  def fed(node) = Array(node.arguments).flat_map { beneath(it) }.grep(Prism::CallNode)

  def beneath(node) = [node] + Hashira::Smells::Scope.inside(node)

  def minted?(node) = mints?(node.name) || spawns?(node.receiver)

  def mints?(name) = MINTS.include?(name)

  def spawns?(receiver) = LITERALS.include?(receiver.class) || SOURCES.include?(receiver&.slice)

  def plain?(node)
    !node.receiver && !node.arguments && !node.block.is_a?(Prism::BlockArgumentNode)
  end

  def repeats
    @_repeats ||= outermost(together(usual.reject { |_handle, nodes| whole.value?(nodes) }.merge(whole)))
  end

  def outermost(groups) = groups.reject { |_handle, nodes| echoed?(nodes, groups) }

  def echoed?(nodes, groups) = groups.each_value.any? { echoes?(nodes, it) }

  def echoes?(inner, outer) = inner.size == outer.size && inside?(inner, outer)

  def inside?(inner, outer) = inner.all? { nested?(it, outer) }

  def nested?(node, outer) = outer.any? { contains?(it, node) }

  def contains?(outer, node) = Hashira::Smells::Scope.inside(outer).any? { it.equal?(node) }

  def together(groups) = groups.select { |_handle, nodes| reachable?(nodes) }

  def reachable?(nodes) = nodes.combination(2).any? { |pair| branches.together?(pair) && !parting?(pair) }

  def parting?(pair) = pair.all? { exits.include?(it) }

  def exits = @_exits ||= Hashira::Smells::Exits.new(subject.node)

  def branches = @_branches ||= Hashira::Smells::Branches.new(subject.node)

  def usual
    calls.reject { plain?(it) }.group_by { handle(it) }
  end

  def whole
    @_whole ||= calls.select { it.block.is_a?(Prism::BlockNode) }.group_by { it.slice.gsub(/\s+/, " ") }
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
