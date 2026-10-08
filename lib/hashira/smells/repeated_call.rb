# frozen_string_literal: true

require "prism"
require_relative "course"
require_relative "lookup"
require_relative "refs"

class Hashira::Smells::RepeatedCall < Hashira::Smells::Check
  MINTS = %i[new dup clone allocate rand srand generate].freeze

  SOURCES = %w[SecureRandom Random].freeze

  LITERALS = [
    Prism::StringNode, Prism::SymbolNode, Prism::ArrayNode, Prism::HashNode,
    Prism::IntegerNode, Prism::FloatNode, Prism::RegularExpressionNode
  ].freeze

  FENCES = (Hashira::Smells::Scope::FENCES + [Prism::DefinedNode]).freeze

  SCOPES = Hashira::Smells::Refs::SCOPES

  MATCHES = [Prism::NumberedReferenceReadNode, Prism::BackReferenceReadNode].freeze

  MATCHED = %i[$~ $LAST_MATCH_INFO].freeze

  private

  def smelly? = repeats.any?

  def rating = repeats.each_value.all? { lesser?(it) } ? { confidence: :low } : {}

  def lesser?(nodes) = Hashira::Smells::Lookup.cheap?(nodes.first) || !reachable?(nodes.reject { preset?(it) })

  def preset?(node) = presets.include?(node)

  def presets = @_presets ||= Set.new.compare_by_identity.merge(defaults)

  def defaults = [subject.node.parameters].compact.flat_map { beneath(it) }

  def every = @_every ||= Hashira::Smells::Scope.below(subject.node, FENCES).grep(Prism::CallNode)

  def calls = @_calls ||= every.reject { commanded?(it) || fresh?(it) || volatile?(it) }

  def commanded?(node) = discards.include?(node)

  def discards = @_discards ||= Hashira::Smells::Discards.new(subject.node)

  def fresh?(node) = minted?(node) || fed(node).any? { minted?(it) }

  def fed(node) = Array(node.arguments).flat_map { beneath(it) }.grep(Prism::CallNode)

  def beneath(node) = [node] + Hashira::Smells::Scope.inside(node)

  def minted?(node) = mints?(node.name) || spawns?(node.receiver)

  def mints?(name) = MINTS.include?(name)

  def spawns?(receiver) = LITERALS.include?(receiver.class) || SOURCES.include?(receiver&.slice)

  def volatile?(node) = beneath(node).any? { matched?(it) }

  def matched?(node)
    case node
    when *MATCHES then true
    when Prism::GlobalVariableReadNode then MATCHED.include?(node.name)
    else node.is_a?(Prism::CallNode) && node.name == :last_match && node.receiver&.slice == "Regexp"
    end
  end

  def plain?(node)
    !node.receiver && !node.arguments && !node.block.is_a?(Prism::BlockArgumentNode)
  end

  def repeats = @_repeats ||= outermost(together(alike(usual).merge(alike(whole))))

  def outermost(groups) = groups.reject { |_handle, nodes| echoed?(nodes, groups) }

  def echoed?(nodes, groups) = groups.each_value.any? { echoes?(nodes, it) }

  def echoes?(inner, outer) = inner.size == outer.size && inside?(inner, outer)

  def inside?(inner, outer) = inner.all? { nested?(it, outer) }

  def nested?(node, outer) = outer.any? { contains?(it, node) }

  def contains?(outer, node) = Hashira::Smells::Scope.inside(outer).any? { it.equal?(node) }

  def together(groups) = groups.select { |_handle, nodes| reachable?(nodes) }

  def reachable?(nodes) = nodes.combination(2).any? { |pair| branches.together?(pair) && !course.parted?(pair) }

  def course = @_course ||= Hashira::Smells::Course.new(subject.node, every, discards, branches)

  def branches = @_branches ||= Hashira::Smells::Branches.new(subject.node)

  def usual = calls.reject { plain?(it) || literal?(it) }.group_by { handle(it) }

  def whole = calls.select { literal?(it) }.group_by { it.slice.gsub(/\s+/, " ") }

  def literal?(node) = node.block.is_a?(Prism::BlockNode)

  def alike(groups) = groups.reject { |_text, nodes| nodes.one? }.flat_map { |text, nodes| split(text, nodes) }.to_h

  def split(text, nodes) = nodes.group_by { binding(it) }.map { |held, same| [[text, held], same] }

  def binding(node) = [bindings.free(node), enclosure(node)]

  def bindings = @_bindings ||= Hashira::Smells::Bindings.new(subject.node)

  def enclosure(node) = blocks.reverse.find { Hashira::Smells::Scope.covers?(it, node) }&.location&.start_offset

  def blocks = @_blocks ||= Hashira::Smells::Scope.inside(subject.node).select { SCOPES.include?(it.class) }

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
    repeats.map { |(handle, _), nodes| "#{handle} × #{nodes.size} (#{stamp(lines(nodes))})" }
  end

  def lines(nodes) = nodes.map { it.location.start_line }.uniq

  def stamp(lines) = "line#{"s" if lines.size > 1} #{lines.join(", ")}"
end
