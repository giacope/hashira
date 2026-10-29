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

  class Relay
    ADVICE = "Let callers talk to the delegate directly, or give the class work of its own."

    def initialize(site, delegate, count, total)
      @site = site
      @delegate = delegate
      @count = count
      @total = total
    end

    def to_h = { site: @site, delegate: @delegate, count: @count, total: @total }

    def phrase(package)
      "#{package} forwards #{@count} of its #{@total} public methods to #{@delegate} (#{@site}). #{ADVICE}"
    end
  end

  private

  def smelly?
    subject.kind == :class && !declared? && relays.any? && heaviest.size >= threshold(LIMIT) && most? && !decorates?
  end

  def publics = @_publics ||= subject.owned.select(&:public?).reject { it.node.name == CONSTRUCTOR }

  def relays = @_relays ||= publics.reject(&:polymorphic?).flat_map { relay(it) }.group_by(&:first)

  def delegate = @_delegate ||= relays.max_by { |_, found| found.size }.fetch(0)

  def heaviest = relays.fetch(delegate).map(&:last)

  def most? = heaviest.size * 2 > publics.size

  def sweep = @_sweep ||= subject.sweep

  def declared?
    sweep.grep(Prism::CallNode).any? { DECLARED.include?(it.name) } || subject.nodes.grep(Prism::ClassNode).any? { wrapper?(it.superclass) }
  end

  def decorates?
    own = publics - heaviest
    own.any? && own.all? { wraps?(it) }
  end

  def wraps?(method)
    name = method.node.name
    Hashira::Smells::Scope.new(method.node).sweep.grep(Prism::CallNode).any? { it.name == name && targets(it.receiver).include?(delegate) }
  end

  def wrapper?(node) = WRAPPERS.include?(node&.slice.to_s[/\A[\w:]+/].to_s.split("::").last)

  def relay(method)
    calls = sole(method.node).select { !COLLECTION.include?(it.name) && forwards?(it, method) }
    calls.flat_map { |call| targets(call.receiver).map { [it, method] } }
  end

  def forwards?(call, method)
    [*call.arguments&.arguments, call.block].compact.flat_map { passed(it) } == method.parameters
  end

  def sole(definition)
    held = Hashira::Analysis::Syntax::Body.new(definition).to_a
    held.one? && held.first.is_a?(Prism::CallNode) ? held : []
  end

  def targets(receiver)
    case receiver
    when Prism::InstanceVariableReadNode then [receiver.name.to_s]
    when Prism::CallNode then reader?(receiver) ? ["@#{receiver.name}"] : []
    else []
    end
  end

  def reader?(call) = !call.receiver && !call.arguments && readers.include?(call.name.to_s)

  def readers = @_readers ||= Hashira::Smells::Attributes.new(sweep).readers

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

  def detail = Relay.new(site, delegate, heaviest.size, publics.size)

  def evidence = heaviest.map { "#{it.node.name} (line #{it.line})" }
end
