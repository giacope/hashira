# frozen_string_literal: true

require "prism"
require_relative "mapping"
require_relative "recheck"
require_relative "scope"

class Hashira::Smells::RepeatedConditional < Hashira::Smells::Check
  LIMIT = 2

  TYPES = %i[is_a? kind_of? instance_of?].freeze

  COMPARISONS = %i[== != ===].freeze

  FIXED = Hashira::Smells::Mapping::FIXED

  LOCALS = [Prism::LocalVariableReadNode, Prism::ItLocalVariableReadNode].freeze

  SCOPES = (Hashira::Smells::Scope::FENCES + [Prism::BlockNode, Prism::LambdaNode]).freeze

  JOINS = [Prism::AndNode, Prism::OrNode].freeze

  WRAPS = [Prism::ParenthesesNode, Prism::StatementsNode].freeze

  QUERIES = %i[exists? exist? where find_by].freeze

  Test =
    Data.define(:atom, :region, :root) do
      def text = atom.slice

      def key = [text, (region if local?)]

      def local? = ([atom] + Hashira::Smells::Scope.inside(atom)).any? { LOCALS.include?(it.class) }

      def chain = [atom] + receivers(atom)

      def receivers(node) = lead(node).flat_map { [it] + receivers(it) }

      def lead(node) = node.is_a?(Prism::CallNode) ? [node.receiver].compact : []

      def held = receivers(atom).map(&:slice)

      def dispatch? = atom.is_a?(Prism::CallNode) && (TYPES.include?(atom.name) || fixed?)

      def fixed? = COMPARISONS.include?(atom.name) && sides.any? { FIXED.include?(it.class) }

      def sides = [atom.receiver, *atom.arguments&.arguments]

      def queries? = chain.any? { it.is_a?(Prism::CallNode) && QUERIES.include?(it.name) }

      def rechecked?(rechecks) = rechecks.any? { it.settled?(atom, held) }
    end

  private

  def smelly? = subject.kind == :class && repeats.any?

  def repeats = @_repeats ||= groups.select { it.size > threshold(LIMIT) }.uniq { |tests| roots(tests) }

  def roots(tests) = tests.map { it.root.object_id }

  def groups = tests.group_by(&:key).values

  def tests = found.select { it.dispatch? || cased.include?(it.root) }.reject { it.queries? || it.rechecked?(rechecks) }

  def cased = @_cased ||= Set.new.compare_by_identity.merge(subjects)

  def subjects = regions.flat_map { cases(it).filter_map(&:predicate) }

  def cases(region) = Hashira::Smells::Scope.below(region, SCOPES).grep(Prism::CaseNode)

  def found = regions.flat_map { |region| predicates(region).flat_map { |root| split(root, region) } }

  def split(root, region) = atoms(root).map { Test.new(atom: it, region:, root:) }

  def atoms(node)
    case node
    when *JOINS then [node.left, node.right].flat_map { atoms(it) }
    when *WRAPS then parts(node).flat_map { atoms(it) }
    else negated?(node) ? atoms(node.receiver) : [node]
    end
  end

  def parts(node) = Array(node.body)

  def negated?(node) = node.is_a?(Prism::CallNode) && node.name == :!

  def rechecks = @_rechecks ||= subject.sweep.grep(Prism::DefNode).map { Hashira::Smells::Recheck.new(it) }

  def regions = subject.nodes.flat_map { [it] + Hashira::Smells::Scope.sweep(it).select { SCOPES.include?(it.class) } }

  def predicates(region) = Hashira::Smells::Scope.below(region, SCOPES).filter_map { predicate(it) }

  def predicate(node)
    node.predicate if node.is_a?(Prism::IfNode) || node.is_a?(Prism::UnlessNode) || node.is_a?(Prism::CaseNode)
  end

  def detail = { site:, count: repeats.map(&:size).max }

  def evidence = repeats.map { |tests| row(tests.map(&:atom)) }

  def row(nodes)
    "#{nodes.first.slice} × #{nodes.size} (lines #{nodes.map { |node| node.location.start_line }.uniq.sort.join(", ")})"
  end
end
