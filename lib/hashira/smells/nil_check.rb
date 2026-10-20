# frozen_string_literal: true

require "prism"
require_relative "param_check"

class Hashira::Smells::NilCheck < Hashira::Smells::Check
  EQUALITY = %i[== ===].freeze

  HELD = [Prism::LocalVariableReadNode, Prism::InstanceVariableReadNode].freeze

  DEFAULTS = (Hashira::Smells::ParamCheck::FIXED - [Prism::NilNode] + [Prism::ArrayNode, Prism::HashNode]).freeze

  FLAGS = [Prism::TrueNode, Prism::FalseNode].freeze

  FINDERS = %i[find_by].freeze

  RAISES = %i[raise fail].freeze

  BRANCHES = [Prism::IfNode, Prism::UnlessNode, Prism::CaseNode].freeze

  private

  def smelly? = checks.any?

  def checks = @_checks ||= body.select { check?(it) && made?(it) && !excused?(it) }

  def made?(check) = tested(check).any? { provenance.made?(it) }

  def provenance = @_provenance ||= Hashira::Smells::Provenance.new(subject, foreign)

  def body = @_body ||= Hashira::Smells::Scope.inside(subject.node)

  def check?(node)
    case node
    when Prism::CallNode then query?(node) || probe?(node)
    when Prism::WhenNode then node.conditions.any?(Prism::NilNode)
    else shorthand?(node)
    end
  end

  def shorthand?(node)
    case node
    when Prism::UnlessNode then nullable?(node.predicate)
    when Prism::OrNode then fallback?(node)
    else false
    end
  end

  def query?(node)
    name = node.name
    name == :nil? || (EQUALITY.include?(name) && equated?(node))
  end

  def equated?(node) = sides(node).any?(Prism::NilNode)

  def sides(node) = [node.receiver] + (node.arguments&.arguments || [])

  def probe?(call)
    receiver = call.receiver
    call.safe_navigation? ? nullable?(receiver) : (call.name == :blank? && HELD.include?(receiver.class))
  end

  def fallback?(node) = nullable?(node.left) && DEFAULTS.include?(node.right.class)

  def nullable?(node)
    values = assignments(node).map(&:value)
    values.any?(Prism::NilNode) && values.none? { FLAGS.include?(it.class) }
  end

  def assignments(node)
    case node
    when Prism::LocalVariableReadNode then named(body.grep(Prism::LocalVariableWriteNode), node.name)
    when Prism::InstanceVariableReadNode then named(state.grep(Prism::InstanceVariableWriteNode), node.name)
    else []
    end
  end

  def named(nodes, name) = nodes.select { it.name == name }

  def state = @_state ||= Hashira::Smells::Scope.sweep(subject.home)

  def tested(node)
    case node
    when Prism::WhenNode then [chooser(node)]
    when Prism::CallNode then query?(node) ? sides(node).grep_v(Prism::NilNode) : [node.receiver]
    else [node.is_a?(Prism::UnlessNode) ? node.predicate : node.left]
    end
  end

  def chooser(arm) = cases.find { it.conditions.any? { it.equal?(arm) } }.predicate

  def cases = body.grep(Prism::CaseNode)

  def excused?(check) = guard?(check) || defaulted?(check) || raising?(check) || answering?(check)

  def raising?(check) = asserted(check).any? { |branch| Array(branch.statements&.body).any? { raise?(it) } }

  def asserted(check) = body.select { asserts?(it, check) }

  def asserts?(node, check) = BRANCHES.first(2).include?(node.class) && within(node.predicate).any? { it.equal?(check) }

  def raise?(node) = node.is_a?(Prism::CallNode) && !node.receiver && RAISES.include?(node.name)

  def answering?(check) = predicate? && body.none? { BRANCHES.include?(it.class) } && !fetching?(check)

  def fetching?(check) = tested(check).all? { finder?(it) }

  def predicate? = subject.node.then { it.name.end_with?("?") && Hashira::Analysis::Syntax.statements(it).one? }

  def guard?(check)
    validations.validator?(subject.node.name) && tested(check).all? { required?(it) } && !reporting?(check)
  end

  def validations = @_validations ||= Hashira::Smells::Validations.new(subject.home)

  def required?(node) = node.is_a?(Prism::CallNode) && node.variable_call? && validations.required?(node.name)

  def reporting?(check) = steering(check).any? { |branch| Hashira::Smells::Scope.inside(branch).any? { adds?(it) } }

  def steering(check) = body.grep(Prism::IfNode).select { |branch| within(branch.predicate).any? { it.equal?(check) } }

  def within(node) = Hashira::Analysis::NodeWalk.collect(node)

  def adds?(node) = node.is_a?(Prism::CallNode) && node.name == :add && errors?(node.receiver)

  def errors?(node) = node.is_a?(Prism::CallNode) && node.name == :errors

  def defaulted?(check) = tested(check).all? { boundary?(it) } && steering(check).any? { default?(it) }

  def boundary?(node) = parameter?(node) || foreign.entering?(node)

  def parameter?(node) = node.is_a?(Prism::LocalVariableReadNode) && subject.parameters.include?(node.name)

  def default?(branch)
    found = Array(branch.statements&.body)
    found.one? && DEFAULTS.include?(returned(found.first).class)
  end

  def returned(node) = node.is_a?(Prism::ReturnNode) ? Array(node.arguments&.arguments).first : node

  def foreign = @_foreign ||= Hashira::Smells::Foreign.new(subject, subject.ownership)

  def origin = (:absence if absent?)

  def absent? = subject.node.name.end_with?("?") && checks.all? { tested(it).all? { finder?(it) } }

  def finder?(node) = node.is_a?(Prism::CallNode) && FINDERS.include?(node.name)

  def rating = checks.all? { tested(it).all? { external?(it) } } ? { confidence: :low } : {}

  def external?(node) = node.is_a?(Prism::LocalVariableReadNode) && foreign.external?(node.name)

  def detail = { site: spots(checks), origin:, sources: }.compact

  def sources = checks.flat_map { tested(it) }.filter_map { origin_of(it) }.uniq.sort

  def origin_of(node) = Hashira::Smells::Origin.of(node, subject.singleton?)

  def evidence = checks.map { tally(tested(it).map { shown(it) }.join(", "), [it.location.start_line]) }

  def shown(node) = node.slice.lines.first.strip
end
