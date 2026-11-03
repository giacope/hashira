# frozen_string_literal: true

require "prism"
require_relative "param_check"
require_relative "provenance"

class Hashira::Smells::NilCheck < Hashira::Smells::Check
  EQUALITY = %i[== ===].freeze

  HELD = [Prism::LocalVariableReadNode, Prism::InstanceVariableReadNode].freeze

  FLAGS = [Prism::TrueNode, Prism::FalseNode].freeze

  FINDERS = %i[find_by].freeze

  BRANCHES = [Prism::IfNode, Prism::UnlessNode, Prism::CaseNode].freeze

  GUARDS = BRANCHES.first(2).freeze

  ASSIGNS = [Prism::LocalVariableWriteNode, Prism::OptionalParameterNode, Prism::OptionalKeywordParameterNode].freeze

  def initialize(subject, rules, foreign, provenance)
    super(subject, rules)
    @foreign = foreign
    @provenance = provenance
  end

  def findings = sources.empty? ? super : []

  def members
    detail.sightings(label, ratings).map { |key, seen, lines| member(:source, key, seen, cited(lines, spots(checks))) }
  end

  private

  def smelly? = checks.any?

  def checks = @_checks ||= body.select { check?(it) && made?(it) && !excused?(it) }

  def made?(check) = tested(check).any? { provenance.made?(it) }

  attr_reader :foreign, :provenance

  def body = @_body ||= subject.accept(Hashira::Smells::Scope).inside

  def check?(node)
    return query?(node) || probe?(node) if node.is_a?(Prism::CallNode)
    node.is_a?(Prism::WhenNode) ? node.conditions.any?(Prism::NilNode) : shorthand?(node)
  end

  def shorthand?(node)
    node.is_a?(Prism::UnlessNode) ? nullable?(node.predicate) : node.is_a?(Prism::OrNode) && fallback?(node)
  end

  def query?(node) = node.name == :nil? || (EQUALITY.include?(node.name) && equated?(node))

  def equated?(node) = sides(node).any?(Prism::NilNode)

  def sides(node) = [node.receiver] + (node.arguments&.arguments || [])

  def probe?(call)
    receiver = call.receiver
    call.safe_navigation? ? nullable?(receiver) : (call.name == :blank? && HELD.include?(receiver.class))
  end

  def fallback?(node) = nullable?(node.left) && Hashira::Analysis::Syntax::Value.new(node.right).default?

  def nullable?(node)
    values = assignments(node).map(&:value)
    (values.any?(Prism::NilNode) && values.none? { FLAGS.include?(it.class) }) || provenance.source(node).any?
  end

  def assignments(node)
    case node
    when Prism::LocalVariableReadNode then named(body.select { writes.include?(it.class) }, node.name)
    when Prism::InstanceVariableReadNode then named(state.grep(Prism::InstanceVariableWriteNode), node.name)
    else []
    end
  end

  def writes = strict? ? ASSIGNS : ASSIGNS.first(1)

  def named(nodes, name) = nodes.select { it.name == name }

  def state = @_state ||= subject.home.accept(Hashira::Smells::Scope).sweep

  def tested(node)
    case node
    when Prism::WhenNode then [chooser(node)]
    when Prism::CallNode then query?(node) ? sides(node).grep_v(Prism::NilNode) : [node.receiver]
    else [node.is_a?(Prism::UnlessNode) ? node.predicate : node.left]
    end
  end

  def chooser(arm) = body.grep(Prism::CaseNode).find { it.conditions.any? { it.equal?(arm) } }.predicate

  def excused?(check) = guard?(check) || defaulted?(check) || raising?(check) || answering?(check) || memo?(check)

  def memo?(check) = asserted(check).any? { Hashira::Smells::Memo.new(it, check).fills?(tested(check), subject) }

  def raising?(check) = raises.any?(asserted(check).flat_map { Array(it.statements&.body) })

  def raises = subject.home.accept(Hashira::Smells::Raises)

  def asserted(check) = body.select { asserts?(it, check) }

  def asserts?(node, check) = GUARDS.include?(node.class) && [node, *within(node.predicate)].any? { it.equal?(check) }

  def answering?(check) = predicate? && body.none? { BRANCHES.include?(it.class) } && !fetching?(check)

  def fetching?(check) = tested(check).all? { finder?(it) }

  def predicate? = name.end_with?("?") && subject.accept(Hashira::Analysis::Syntax::Body).to_a.one?

  def name = subject.accept(Hashira::Smells::Signature).name

  def guard?(check) = guarded?(check, subject.home.accept(Hashira::Smells::Validations)) && !reporting?(check)

  def guarded?(check, validations)
    validations.validator?(name) && tested(check).all? { required?(it, validations) }
  end

  def required?(node, validations)
    node.is_a?(Prism::CallNode) && node.variable_call? && validations.required?(node.name)
  end

  def reporting?(check) = steering(check).any? { |branch| Hashira::Smells::Scope.new(branch).inside.any? { adds?(it) } }

  def steering(check) = body.grep(Prism::IfNode).select { |branch| within(branch.predicate).any? { it.equal?(check) } }

  def within(node) = Hashira::Analysis::NodeWalk.new(node).collect

  def adds?(node) = node.is_a?(Prism::CallNode) && node.name == :add && errors?(node.receiver)

  def errors?(node) = node.is_a?(Prism::CallNode) && node.name == :errors

  def defaulted?(check) = tested(check).all? { parameter?(it) } && steering(check).any? { default?(it) }

  def parameter?(node) = node.is_a?(Prism::LocalVariableReadNode) && parameters.include?(node.name)

  def parameters = @_parameters ||= subject.accept(Hashira::Smells::Parameters).names

  def default?(branch)
    found = Array(branch.statements&.body)
    found.one? && returned(found.first).any? { Hashira::Analysis::Syntax::Value.new(it).default? }
  end

  def returned(node) = node.is_a?(Prism::ReturnNode) ? Array(node.arguments&.arguments).first(1) : [node]

  def origin = absent? ? :absence : provenance.options(checks.flat_map { tested(it) })

  def absent? = name.end_with?("?") && checks.all? { tested(it).all? { finder?(it) } }

  def finder?(node) = node.is_a?(Prism::CallNode) && FINDERS.include?(node.name)

  def ratings = checks.all? { tested(it).all? { external?(it) } } ? [:low] : []

  def external?(node) = node.is_a?(Prism::LocalVariableReadNode) && foreign.external?(node.name)

  def detail = Hashira::Smells::Doubt.new(spots(checks), origin, sources)

  def sources = @_sources ||= sightings.group_by(&:first).sort.to_h { |name, pairs| [name, spots(pairs.map(&:last))] }

  def sightings = checks.flat_map { |check| tested(check).flat_map { origin_of(it) }.map { [it, check] } }

  def origin_of(node) = provenance.origin(node)

  def evidence = checks.map { tally(tested(it).map { shown(it) }.join(", "), [it.location.start_line]) }

  def shown(node) = node.slice.lines.first.strip
end
