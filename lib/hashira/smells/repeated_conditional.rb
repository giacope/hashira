# frozen_string_literal: true

require "prism"
require_relative "mapping"
require_relative "recheck"
require_relative "scope"

class Hashira::Smells::RepeatedConditional < Hashira::Smells::Check
  LIMIT = 2

  TYPES = %i[is_a? kind_of? instance_of?].freeze

  COMPARISONS = %i[== != ===].freeze

  LOCALS = [Prism::LocalVariableReadNode, Prism::ItLocalVariableReadNode].freeze

  JOINS = [Prism::AndNode, Prism::OrNode].freeze

  WRAPS = [Prism::ParenthesesNode, Prism::StatementsNode].freeze

  QUERIES = %i[exists? exist? where find_by].freeze

  class Echoes
    def initialize(site, count)
      @site = site
      @count = count
    end

    def to_h = { site: @site, count: @count }

    def phrase(package)
      "#{package} branches on the same test #{@count} times (#{@site}). Replace the scattered checks with polymorphism."
    end
  end

  class Test
    def initialize(atom, region, root)
      @atom = atom
      @region = region
      @root = root
    end

    def key = [@atom.slice, (@region if local?)]

    def counts?(cased, rechecks) = (dispatch? || cased.include?(@root)) && !queries? && !rechecked?(rechecks)

    def origin = @root.object_id

    def cue = [@atom.slice, @atom.location.start_line]

    private

    def local? = ([@atom] + Hashira::Smells::Scope.new(@atom).inside).any? { LOCALS.include?(it.class) }

    def chain = [@atom] + receivers(@atom)

    def receivers(node) = lead(node).flat_map { [it] + receivers(it) }

    def lead(node) = node.is_a?(Prism::CallNode) ? [node.receiver].compact : []

    def held = receivers(@atom).map(&:slice)

    def dispatch? = @atom.is_a?(Prism::CallNode) && (TYPES.include?(@atom.name) || fixed?)

    def fixed? = COMPARISONS.include?(@atom.name) && sides.any? { Hashira::Analysis::Syntax.new(it).fixed? }

    def sides = [@atom.receiver, *@atom.arguments&.arguments]

    def queries? = chain.any? { it.is_a?(Prism::CallNode) && QUERIES.include?(it.name) }

    def rechecked?(rechecks) = rechecks.any? { it.settled?(@atom, held) }
  end

  private

  def smelly? = subject.kind == :class && repeats.any?

  def repeats = @_repeats ||= groups.select { it.size > threshold(LIMIT) }.uniq { |tests| roots(tests) }

  def roots(tests) = tests.map(&:origin)

  def groups = tests.group_by(&:key).values

  def tests = found.select { it.counts?(cased, rechecks) }

  def cased = @_cased ||= Set.new.compare_by_identity.merge(subjects)

  def subjects = regions.flat_map { cases(it).filter_map(&:predicate) }

  def cases(region) = Hashira::Smells::Scope.new(region).bare.grep(Prism::CaseNode)

  def found = regions.flat_map { |region| predicates(region).flat_map { |root| split(root, region) } }

  def split(root, region) = atoms(root).map { Test.new(it, region, root) }

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

  def regions
    subject.nodes.flat_map { [it] + Hashira::Smells::Scope.new(it).sweep.select { opens?(it) } }
  end

  def opens?(node) = Hashira::Smells::Scope.new(node).then { it.fence? || it.closure? }

  def predicates(region) = Hashira::Smells::Scope.new(region).bare.filter_map { predicate(it) }

  def predicate(node)
    node.predicate if node.is_a?(Prism::IfNode) || node.is_a?(Prism::UnlessNode) || node.is_a?(Prism::CaseNode)
  end

  def detail = Echoes.new(site, repeats.map(&:size).max)

  def evidence = repeats.map { |tests| row(tests.map(&:cue)) }

  def row(cues) = "#{cues.first.first} × #{cues.size} (lines #{cues.map(&:last).uniq.sort.join(", ")})"
end
