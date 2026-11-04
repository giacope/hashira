# frozen_string_literal: true

require "prism"

class Hashira::Smells::Switches
  class Arm
    def initialize(subject, case_label)
      @subject = subject
      @case_label = case_label
    end

    def topic = @subject.slice

    def tested? = yield(@subject)

    def label = @case_label.slice

    def line = @case_label.location.start_line
  end

  class Switch
    def initialize(topic, arms)
      @topic = topic
      @arms = arms
    end

    def wide?(least) = labels.size >= least

    def lines = @arms.map(&:line).uniq.sort

    def to_s = "#{@topic}: #{labels.join(", ")}"

    private

    def labels = @arms.map(&:label).uniq
  end

  MIN_ARMS = 2

  STATUS = /(?:\A@?|_)(?:status|state|type|kind)\z/

  VALUES = [Prism::SymbolNode, Prism::StringNode, Prism::IntegerNode].freeze

  TYPE_NAME = /[a-z]/

  def initialize(node, names, owner = nil)
    @node = node
    @names = names
    @owner = owner
  end

  def typed = @_typed ||= gathered(tests)

  def held = tests.select { |arm| arm.tested? { own?(it) } }

  def statuses
    @_statuses ||= gathered(
      cased(dispatches) { VALUES.include?(it.class) }.select do |arm|
        arm.tested? do
          status?(it)
        end
      end
    )
  end

  private

  def body = @_body ||= Hashira::Smells::Scope.new(@node).inside

  def gathered(arms)
    arms.group_by(&:topic).map { |text, found| Switch.new(text, found) }.select { it.wide?(MIN_ARMS) }
  end

  def cased(cases = selected, &) = cases.flat_map { |node| arms(node, &) }

  def selected = body.grep(Prism::CaseNode).select(&:predicate)

  def dispatches = selected.reject { lookup?(it) }

  def lookup?(node) = [*node.conditions, node.else_clause].compact.all? { Hashira::Smells::Mapping.new(it).literal? }

  def arms(node)
    node.conditions.flat_map { |branch| branch.conditions.select { yield(it) }.map { arm(node.predicate, it) } }
  end

  def probed = body.grep(Prism::CallNode).filter_map { probe(it) }

  def probe(call)
    probed = call.receiver
    tested = Array(call.arguments&.arguments).first
    arm(probed, tested) if Hashira::Analysis::Syntax::Message.new(call).type_test? && probed && type?(tested)
  end

  def arm(subject, label) = Arm.new(subject, label)

  def type?(node)
    segments = Hashira::Analysis::Syntax.new(node).segments
    segments.any? && TYPE_NAME.match?(segments.last) && @names.owns?(node, @owner)
  end

  def tests = @_tests ||= cased { type?(it) } + probed

  def status?(node) = own?(node) && STATUS.match?(node.name)

  def own?(node)
    case node
    when Prism::InstanceVariableReadNode then true
    when Prism::CallNode then [nil, Prism::SelfNode].include?(node.receiver&.class)
    else false
    end
  end
end
