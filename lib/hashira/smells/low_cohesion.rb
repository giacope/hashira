# frozen_string_literal: true

require "prism"
require_relative "common"
require_relative "lineal"

class Hashira::Smells::LowCohesion < Hashira::Smells::Lineal
  SIZE = 6

  MEMBERS = 2

  CONSTRUCTOR = :initialize

  FIELDS = [
    Prism::InstanceVariableReadNode, Prism::InstanceVariableWriteNode, Prism::InstanceVariableOrWriteNode,
    Prism::InstanceVariableAndWriteNode, Prism::InstanceVariableOperatorWriteNode, Prism::InstanceVariableTargetNode
  ].freeze

  READS = [
    Prism::InstanceVariableReadNode, Prism::InstanceVariableOperatorWriteNode, Prism::InstanceVariableAndWriteNode
  ].freeze

  INTERPOLATED = [Prism::InterpolatedSymbolNode, Prism::InterpolatedStringNode].freeze

  LISTING = :instance_variables

  RECORD = /(?:\A|::)(?:ApplicationRecord|ActiveRecord::Base)\z/

  STOCK = Hashira::Smells::Common.new

  MESSAGES = Hashira::Runtime::Messages.new

  PRESENTATION = /(?:Controller|Mailer|Job|Channel|Mailbox)(?:::[A-Z]\w*)?\z/

  PEEK = :instance_variable_get

  class Seams
    def initialize(site, count, size)
      @site = site
      @count = count
      @size = size
    end

    def to_h = { site: @site, count: @count, size: @size }

    def phrase(package)
      "#{package} splits into #{@count} groups of methods that share no state (#{@site}). " \
        "Split the class along that seam."
    end
  end

  def self.build(subject, rules, family)
    sweep = subject.bulk.sweep
    new(subject, rules, family, Hashira::Smells::Forwards.new(sweep, Hashira::Smells::Bonds.new(sweep), STOCK))
  end

  def initialize(subject, rules, family, forwards)
    super(subject, rules, family)
    @forwards = forwards
  end

  private

  attr_reader :forwards

  def sweep = @_sweep ||= subject.bulk.sweep

  def smelly? = subject.first.seat.class? && methods.size >= threshold(SIZE) && !framed? && groups.size > 1

  def framed? = strict? ? presented? : family.framing.framed?(label)

  def presented? = [label, root].any? { PRESENTATION.match?(it) }

  def root = @_root ||= family.framing.root(label)

  def methods = @_methods ||= owned.reject { constructor?(it) }

  def constructor?(method) = selector(method) == CONSTRUCTOR

  def names = @_names ||= methods.to_set { selector(it) }

  def groups = @_groups ||= components.select { |members, fields| fields.any? && members.size >= MEMBERS }

  def components = pieces.reduce([]) { |found, piece| fuse(found, piece) }.map { it.kept(names, kept) }

  def pieces = (methods + mixed).map { piece(selector(it), below(it), []) } + setup.map { piece(nil, it, inputs) }

  def below(method) = hooked(method).flat_map { it.accept(Hashira::Smells::Below).to_a }

  def hooked(method) = [method, *(kin.overrides(label, selector(method)) if abstract?(method))]

  def every(node) = Hashira::Analysis::NodeWalk.new(node).collect

  def abstract?(method) = method.accept(Hashira::Smells::Refusal).unimplemented?

  def mixed = @_mixed ||= kin.mixed(subject.to_s)

  def kin = family.inheritance

  def known = @_known ||= names | mixed.to_set { selector(it) }

  def piece(name, found, given)
    shared = found.grep(Prism::LocalVariableReadNode).map(&:name) & given
    Hashira::Smells::Piece.new([name], fields(found) + shared.map { :"(#{it})" }, calls(found))
  end

  def inputs = constructors.flat_map { it.accept(Hashira::Smells::Parameters).names }

  def setup = constructors.flat_map { it.accept(Hashira::Analysis::Syntax::Body).to_a.compact }.map { every(it) }

  def constructors = @_constructors ||= built(owned).then { it.empty? ? bequeathed : it }

  def bequeathed = family.tree.ancestors(subject.to_s).lazy.map { built(kin.definitions(it)) }.find(&:any?) || []

  def built(methods) = methods.select { constructor?(it) }

  def fuse(found, piece)
    touching, apart = found.partition { it.linked?(piece) }
    apart + [(touching + [piece]).reduce { |all, part| all.merge(part) }]
  end

  def fields(found) = (touched(found) + attributed(found) + reached(found) + (peeks?(found) ? kept.to_a : [])).uniq

  def peeks?(found) = selves(found).any? { it.name == LISTING || (it.name == PEEK && computed?(it)) }

  def computed?(call) = call.arguments && !Hashira::Analysis::Syntax::Word.new(call.arguments.arguments.first).word?

  def touched(found) = Hashira::Smells::Fields.new(found).named(FIELDS)

  def attributed(found)
    selves(found).filter_map { attributes[it.name.to_s.delete_suffix("=")] } + columned(Hashira::Smells::Columns.new(found).touched)
  end

  def columned(names) = record? ? names.reject { declared?(it) }.map { forwards.field(it) } : []

  def declared?(name)
    [known, STOCK, forwards.names].any? { it.include?(name) } || MESSAGES.kernel?(name) || attributes.key?(name.to_s)
  end

  def record? = RECORD.match?(root)

  def columns = columned(Hashira::Smells::Columns.new(sweep).read).to_set

  def calls(found) = (selves(found).map(&:name) + sent(found)).select { known.include?(it) }.uniq

  def selves(found) = found.grep(Prism::CallNode).select { inward?(it.receiver) }

  def inward?(receiver) = receiver.nil? || receiver.is_a?(Prism::SelfNode)

  def sent(found)
    dispatched = selves(found).select { Hashira::Analysis::Syntax::Message.new(it).dispatch? }
    dispatched.flat_map { Array(it.arguments&.arguments).first(1) }.flat_map { aimed(it) }
  end

  def reached(found) = sent(found).filter_map { attributes[it.to_s.delete_suffix("=")] }

  def aimed(name)
    return [Hashira::Analysis::Syntax::Word.new(name).symbol] if Hashira::Analysis::Syntax::Word.new(name).word?
    INTERPOLATED.include?(name.class) ? affixed(name) : tabled
  end

  def affixed(name)
    head, tail = Hashira::Coupling::Affixes.new(name.parts).to_a
    return writers.select { it.start_with?(head) } if written?(name)
    return tabled if head.empty? && tail.empty?
    names.select { it.start_with?(head) && it.end_with?(tail) }
  end

  def written?(name) = Hashira::Analysis::Syntax::Word.new(name.parts.last).to_a == [:"="]

  def writers = @_writers ||= names.select { it.end_with?("=") } + Hashira::Smells::Attributes.new(sweep).writers

  def tabled = @_tabled ||= names.select { listed.include?(it) }

  def listed = sweep.grep(Prism::SymbolNode).map { Hashira::Analysis::Syntax::Word.new(it).to_s }.to_set(&:to_sym)

  def attributes
    @_attributes ||= Hashira::Smells::Attributes.new(sweep).declared.to_h { [it, :"@#{it}"] }.merge(forwards.to_h)
  end

  def kept = @_kept ||= sweep.select { READS.include?(it.class) }.to_set(&:name) | attributes.values | columns

  def detail = Seams.new(site, groups.size, methods.size)

  def evidence = groups.map { |members, fields| "#{members.join(", ")} (#{fields.sort.join(", ")})" }
end
