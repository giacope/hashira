# frozen_string_literal: true

require "prism"

class Hashira::Smells::Switches
  Arm = Data.define(:subject, :label, :line)

  Switch =
    Data.define(:subject, :arms) do
      def labels = arms.map(&:label).uniq

      def lines = arms.map(&:line).uniq.sort
    end

  MIN_ARMS = 2

  STATUS = /(?:\A@?|_)(?:status|state|type|kind)\z/

  NAMED = [Prism::CallNode, Prism::LocalVariableReadNode, Prism::InstanceVariableReadNode].freeze

  VALUES = [Prism::SymbolNode, Prism::StringNode, Prism::IntegerNode].freeze

  TYPE_NAME = /[a-z]/

  def initialize(node, ownership)
    @node = node
    @ownership = ownership
  end

  def typed = @_typed ||= gathered(cased { type?(it) } + probed)

  def statuses = @_statuses ||= gathered(cased { VALUES.include?(it.class) }.select { status?(it.subject) })

  private

  def body = @_body ||= Hashira::Smells::Scope.inside(@node)

  def gathered(arms)
    arms.group_by { it.subject.slice }.map { |text, found| Switch.new(text, found) }
      .select { it.labels.size >= MIN_ARMS }
  end

  def cased(&)
    body.grep(Prism::CaseNode).select(&:predicate).flat_map { |node| arms(node, &) }
  end

  def arms(node)
    node.conditions.flat_map { |branch| branch.conditions.select { yield(it) }.map { arm(node.predicate, it) } }
  end

  def probed = body.grep(Prism::CallNode).filter_map { probe(it) }

  def probe(call)
    probed = call.receiver
    tested = Array(call.arguments&.arguments).first
    arm(probed, tested) if Hashira::Smells::Foreign::TYPE_TESTS.include?(call.name) && probed && type?(tested)
  end

  def arm(subject, label) = Arm.new(subject, label.slice, label.location.start_line)

  def type?(node)
    segments = Hashira::Analysis::Syntax.segments(node)
    segments.any? && TYPE_NAME.match?(segments.last) && @ownership.owned?(segments)
  end

  def status?(node) = NAMED.include?(node.class) && STATUS.match?(node.name)
end
