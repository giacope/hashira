# frozen_string_literal: true

require "prism"

class Hashira::Smells::StatefulMixin < Hashira::Smells::Check
  FIELDS = %i[
    attr_reader attr_writer attr_accessor class_attribute attribute store_accessor serialize
    belongs_to has_one has_many has_and_belongs_to_many
  ].freeze

  SHARED = %i[
    mattr_reader mattr_writer mattr_accessor cattr_reader cattr_writer cattr_accessor
    thread_mattr_reader thread_mattr_writer thread_mattr_accessor
    thread_cattr_reader thread_cattr_writer thread_cattr_accessor
  ].freeze

  HOOKS = /\A(?:(?:before|after|around)_\w+|validates?(?:_\w+)?)\z/

  KEPT = [
    Prism::InstanceVariableWriteNode, Prism::InstanceVariableOperatorWriteNode,
    Prism::InstanceVariableAndWriteNode, Prism::InstanceVariableTargetNode
  ].freeze

  INCLUDED = :included

  LIFTED = %i[singleton].freeze

  MIXED = %i[module_function].freeze

  class Mixing
    ADVICE = "Make it a decorator: wrap the host and reach it through its public methods."

    def initialize(site, uses)
      @site = site
      @uses = uses
    end

    def to_h = { site: @site, uses: @uses }

    def phrase(package) = "#{package} mixes behavior into its host's own state (#{@site}). #{ADVICE}"
  end

  private

  def smelly? = mixin? && (lent.any? || !lifted?) && !bulk.singular? && uses.any? && bulk.legible?

  def bulk = subject.bulk

  def lifted? = subject.any? { |opening| opening.any? { it.standing.in?(LIFTED) } }

  def mixin?
    !subject.first.seat.class? && subject.claimed? && subject.any? { it.accept(Hashira::Smells::Heading).module? }
  end

  def lent = @_lent ||= owned.reject { it.standing.in?(MIXED) }

  def statements = @_statements ||= bulk.statements

  def uses = @_uses ||= grouped.map { |name, seen| tally(name, lines(seen)) }

  def grouped = (read + kept + installed).group_by(&:first).sort_by { |_, seen| lines(seen).min }

  def lines(seen) = seen.map(&:last).uniq.sort

  def read
    lot = subject.lot
    lent.flat_map { harvest(it) }.reject { |name, _| lot.assigned?(name) { own } || cache?(name) }
      .map { |name, line| ["reads #{name}", line] }
  end

  def own = @_own ||= subject.flat_map { installs(it).names }

  def installs(opening) = Hashira::Smells::Installs.new(opening, opening.accept(Hashira::Smells::Scope).sweep)

  def harvest(definition)
    definition.accept(Hashira::Smells::Scope).inside.grep(Prism::InstanceVariableReadNode).map { [it.name, line(it)] }
  end

  def kept
    lent.flat_map { it.accept(Hashira::Smells::Scope).inside.select { KEPT.include?(it.class) } }
      .reject { cache?(it.name) }.map { ["keeps #{it.name} in its host", line(it)] }
  end

  def cache?(name) = name.start_with?("@_")

  def installed = hooked.select { installs?(it) }.map { ["installs #{it.name}", line(it)] }

  def hooked = (inner + included.flat_map { Hashira::Smells::Scope.new(it).inside }).reject { aside?(it) }

  def inner = subject.flat_map { it.accept(Hashira::Smells::Scope).inside }

  def aside?(node) = asides.any? { Hashira::Smells::Extent.new(it).covers?(node) }

  def asides = @_asides ||= bulk.sweep.select { Hashira::Analysis::Syntax::Message.new(it).apart? }.map(&:block)

  def included = @_included ||= statements.grep(Prism::DefNode).select { it.name == INCLUDED && it.receiver }

  def installs?(node) = node.is_a?(Prism::CallNode) && (field?(node) || shared?(node))

  def field?(call) = host?(call.receiver) && (FIELDS.include?(call.name) || HOOKS.match?(call.name.to_s))

  def shared?(call) = SHARED.include?(call.name) && (based?(call.receiver) || hosted?(call))

  def hosted?(call) = Hashira::Smells::Origin.new(call.receiver).self? && hosts.any? { it.covers?(call) }

  def hosts = @_hosts ||= hooks.map { Hashira::Smells::Extent.new(it) }

  def hooks = statements.grep(Prism::CallNode).select { it.name == INCLUDED }

  def host?(receiver) = Hashira::Smells::Origin.new(receiver).self? || based?(receiver)

  def based?(receiver) = receiver.is_a?(Prism::LocalVariableReadNode) && bases.include?(receiver.name)

  def bases = @_bases ||= included.flat_map { Hashira::Smells::Parameters.new(it).names }

  def line(node) = node.location.start_line

  def detail = Mixing.new(site, uses.size)

  def evidence = uses
end
