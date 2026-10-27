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

  def lesser?(nodes) = cheap?(nodes) || !reachable?(nodes.reject { preset?(it) })

  def cheap?(nodes) = Hashira::Smells::Lookup.new(nodes.first, subject.home).cheap?

  def preset?(node) = presets.include?(node)

  def presets = @_presets ||= Set.new.compare_by_identity.merge(defaults)

  def defaults = [subject.node.parameters].compact.flat_map { beneath(it) }

  def every = @_every ||= Hashira::Smells::Scope.new(subject.node).below(FENCES).grep(Prism::CallNode)

  def calls = @_calls ||= every.reject { commanded?(it) || fresh?(it) || volatile?(it) }

  def commanded?(node) = discards.include?(node)

  def discards = @_discards ||= Hashira::Smells::Discards.new(subject.node)

  def fresh?(node) = minted?(node) || fed(node).any? { minted?(it) }

  def fed(node) = Array(node.arguments).flat_map { beneath(it) }.grep(Prism::CallNode)

  def beneath(node) = [node] + Hashira::Smells::Scope.new(node).inside

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

  def repeats = @_repeats ||= collapsed(outermost(together(found)).reject { |_, nodes| excused?(nodes) })

  def collapsed(groups)
    held = Set.new.compare_by_identity.merge(groups.values.flatten)
    groups.reject { |_handle, nodes| nodes.all? { prefixed?(it, held) } }
  end

  def prefixed?(node, held)
    receiver = node.receiver
    receiver.is_a?(Prism::CallNode) && (held.include?(receiver) || prefixed?(receiver, held))
  end

  def found = alike(usual).merge(alike(whole))

  def excused?(nodes) = glance?(nodes) || sampling.sampled?(nodes)

  def glance?(nodes) = cheap?(nodes) && nodes.combination(3).none? { thrice?(it) }

  def thrice?(trio) = trio.combination(2).all? { reachable?(it) }

  def sampling = @_sampling ||= Hashira::Smells::Sampling.new(subject.node, every)

  def outermost(groups) = groups.reject { |_handle, nodes| echoed?(nodes, groups) }

  def echoed?(nodes, groups) = groups.each_value.any? { echoes?(nodes, it) }

  def echoes?(inner, outer) = inner.size == outer.size && inside?(inner, outer)

  def inside?(inner, outer) = inner.all? { nested?(it, outer) }

  def nested?(node, outer) = outer.any? { contains?(it, node) }

  def contains?(outer, node) = Hashira::Smells::Scope.new(outer).inside.any? { it.equal?(node) }

  def together(groups) = groups.select { |_handle, nodes| reachable?(nodes) }

  def reachable?(nodes) = nodes.combination(2).any? { |pair| branches.together?(pair) && !parted?(pair) }

  def parted?(pair) = course.parted?(pair) || retries.retry?(*pair)

  def retries = @_retries ||= Hashira::Smells::Retries.new(subject.node)

  def course = @_course ||= Hashira::Smells::Course.new(subject.node, every, discards, branches)

  def branches = @_branches ||= Hashira::Smells::Branches.new(subject.node)

  def usual = calls.reject { plain?(it) || literal?(it) }.group_by { handle(it) }

  def whole = calls.select { literal?(it) }.group_by { it.slice.gsub(/\s+/, " ") }

  def literal?(node) = node.block.is_a?(Prism::BlockNode)

  def alike(groups) = groups.reject { |_text, nodes| nodes.one? }.flat_map { |text, nodes| split(text, nodes) }.to_h

  def split(text, nodes) = nodes.group_by { binding(it) }.map { |held, same| [[text, held], same] }

  def binding(node) = [bindings.free(node), enclosure(node)]

  def bindings = @_bindings ||= Hashira::Smells::Bindings.new(subject.node)

  def enclosure(node) = blocks.reverse.find { Hashira::Smells::Scope.new(it).covers?(node) }&.location&.start_offset

  def blocks = @_blocks ||= Hashira::Smells::Scope.new(subject.node).inside.select { SCOPES.include?(it.class) }

  def handle(node) = index?(node) ? indexed(node) : "#{title(node)}#{signature(node)}"

  def indexed(node) = "#{node.receiver.slice}[#{node.arguments.slice}]"

  def index?(node) = node.name == :[] && node.receiver && node.arguments

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
