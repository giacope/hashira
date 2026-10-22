# frozen_string_literal: true

require "prism"

class Hashira::Smells::MiddleMan < Hashira::Smells::Check
  LIMIT = 3

  DECLARED = %i[
    def_delegator def_delegators def_instance_delegator def_instance_delegators delegate delegate_missing_to
  ].freeze

  WRAPPERS = %w[SimpleDelegator DelegateClass Delegator].freeze

  COLLECTION = %i[
    each each_with_index map size length count empty? any? none? [] []= first last include? key? fetch dig
    to_a to_h keys values push << delete clear
  ].freeze

  CONSTRUCTOR = :initialize

  Relay = Data.define(:site, :delegate, :count, :total)

  private

  def smelly? = subject.kind == :class && !declared? && relays.any? && heaviest.size >= threshold(LIMIT) && most?

  def publics = @_publics ||= subject.owned.select(&:public?).reject { it.node.name == CONSTRUCTOR }

  def relays = @_relays ||= publics.reject(&:polymorphic?).filter_map { relay(it) }.group_by(&:first)

  def delegate = @_delegate ||= relays.max_by { |_, found| found.size }.first

  def heaviest = relays.fetch(delegate).map(&:last)

  def most? = heaviest.size * 2 > publics.size

  def sweep = @_sweep ||= subject.sweep

  def declared?
    sweep.grep(Prism::CallNode).any? { DECLARED.include?(it.name) } || subject.nodes.any? { wrapper?(it.superclass) }
  end

  def wrapper?(node) = WRAPPERS.include?(node&.slice.to_s[/\A[\w:]+/].to_s.split("::").last)

  def relay(method)
    call = sole(method.node)
    return unless call && !COLLECTION.include?(call.name)
    return unless [*call.arguments&.arguments, call.block].compact.flat_map { passed(it) } == method.parameters
    target = target(call.receiver)
    [target, method] if target
  end

  def sole(definition)
    held = Hashira::Analysis::Syntax.new(definition).statements
    held.first if held.one? && held.first.is_a?(Prism::CallNode)
  end

  def target(receiver)
    case receiver
    when Prism::InstanceVariableReadNode then receiver.name.to_s
    when Prism::CallNode then "@#{receiver.name}" if reader?(receiver)
    end
  end

  def reader?(call) = !call.receiver && !call.arguments && readers.include?(call.name.to_s)

  def readers = @_readers ||= Hashira::Smells::Attributes.new(sweep).declared(Hashira::Smells::Attributes::READERS)

  def passed(node)
    case node
    when Prism::LocalVariableReadNode then [node.name]
    when Prism::SplatNode, Prism::BlockArgumentNode then Array(node.expression).flat_map { passed(it) }
    when Prism::AssocSplatNode, Prism::AssocNode, Prism::ImplicitNode then Array(node.value).flat_map { passed(it) }
    when Prism::KeywordHashNode then node.elements.flat_map { passed(it) }
    when Prism::ForwardingArgumentsNode then []
    else [nil]
    end
  end

  def detail = Relay.new(site:, delegate:, count: heaviest.size, total: publics.size)

  def evidence = heaviest.map { "#{it.node.name} (line #{it.line})" }
end
