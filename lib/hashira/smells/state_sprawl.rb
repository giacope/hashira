# frozen_string_literal: true

require "prism"

class Hashira::Smells::StateSprawl < Hashira::Smells::Check
  Sprawl = Data.define(:site, :count, :weight, :limit)

  LIMIT = 4

  COUNTED = [
    Prism::InstanceVariableWriteNode, Prism::InstanceVariableAndWriteNode,
    Prism::InstanceVariableOperatorWriteNode, Prism::InstanceVariableTargetNode
  ].freeze

  TOUCHED = (COUNTED + [Prism::InstanceVariableReadNode, Prism::InstanceVariableOrWriteNode]).freeze

  READS = [
    Prism::InstanceVariableReadNode, Prism::InstanceVariableOperatorWriteNode,
    Prism::InstanceVariableAndWriteNode, Prism::InstanceVariableOrWriteNode
  ].freeze

  READERS = %i[attr_reader attr_accessor].freeze

  CONSTRUCTOR = :initialize

  NOTES = { 0 => " (read by no method: handed off)", 1 => "", 2 => " (parked between calls)" }.freeze

  GIVEN = " (given to the constructor)"

  private

  def smelly? = subject.kind == :class && weight > limit && !cohesive?

  def limit = threshold(LIMIT)

  def weight = names.sum { heft(it) }

  def heft(name)
    return 0 if given.include?(name)
    return 1 unless stray?(name)
    return 2 if parked.include?(name)
    read?(name) ? 1 : 0
  end

  def given = @_given ||= names.select { |name| writes.select { it.name == name }.all? { handed?(it) } }

  def handed?(write) = setup.include?(write) && passed?(write)

  def passed?(write) = argument?(write.is_a?(Prism::InstanceVariableWriteNode) ? write.value : paired[write])

  def paired
    @_paired ||= setup.grep(Prism::MultiWriteNode).each_with_object({}.compare_by_identity) { |multi, found| pair(multi, found) }
  end

  def pair(multi, found)
    values = multi.value
    return unless values.is_a?(Prism::ArrayNode) && values.elements.none?(Prism::SplatNode)
    multi.lefts.zip(values.elements).each { |target, value| found[target] = value }
  end

  def argument?(value) = value.is_a?(Prism::LocalVariableReadNode) && inputs.include?(value.name)

  def setup = @_setup ||= Set.new.compare_by_identity.merge(sweeps(constructors))

  def inputs = @_inputs ||= constructors.flat_map { Hashira::Smells::Parameters.names(it) }

  def stray?(name) = written(strays).include?(name) && !written(founders).include?(name)

  def parked = @_parked ||= names.select { stray?(it) && carried?(it) }

  def carried?(name) = exposed.include?(name) || methods.any? { taken?(it, name) }

  def taken?(method, name) = reads(within(method)).include?(name) && !written([method]).include?(name)

  def read?(name) = exposed.include?(name) || reads(nodes).include?(name)

  def reads(found) = Hashira::Smells::Attributes.ivars(found, READS)

  def exposed = @_exposed ||= exposing.grep(Prism::SymbolNode).map { field(it) }

  def field(symbol) = :"@#{Hashira::Analysis::Syntax.text(symbol)}"

  def exposing = readers.flat_map { Array(it.arguments&.arguments) }

  def readers = nodes.grep(Prism::CallNode).select { READERS.include?(it.name) }

  def strays = methods.reject(&:receiver) - founders

  def written(methods) = sweeps(methods).select { COUNTED.include?(it.class) }.map(&:name)

  def founders = methods.select { founding.include?(it.name) }

  def founding = @_founding ||= [CONSTRUCTOR] + helpers.map(&:name) + registered

  def registered
    Hashira::Analysis::Syntax.symbol_names(hooks.flat_map { Array(it.arguments&.arguments) }).map(&:to_sym)
  end

  def hooks = bodies.grep(Prism::CallNode).select { hook?(it) }

  def bodies = subject.nodes.flat_map { Hashira::Analysis::Syntax.statements(it) }

  def hook?(call) = !call.receiver && !Hashira::Analysis::TypeWalk::MARKERS.include?(call.name)

  def helpers = sweeps(constructors).grep(Prism::CallNode).reject(&:receiver)

  def sweeps(methods) = methods.flat_map { within(it) }

  def within(method) = (@_within ||= {}.compare_by_identity)[method] ||= Hashira::Analysis::NodeWalk.collect(method)

  def constructors = methods.select { it.name == CONSTRUCTOR }

  def methods = @_methods ||= nodes.grep(Prism::DefNode)

  def cohesive? = parked.empty? && clusters.one?

  def clusters = touches.reduce(names.zip) { |groups, used| fuse(groups, used) }

  def touches = (methods - constructors).map { touched(it) }.reject(&:empty?)

  def touched(method) = within(method).select { TOUCHED.include?(it.class) }.map(&:name) & names

  def fuse(groups, used)
    joined, apart = groups.partition { it.intersect?(used) }
    apart + [joined.flatten]
  end

  def names
    @_names ||= writes.map(&:name).uniq.reject { it.start_with?("@_") || memoized?(it) }.sort
  end

  def nodes = @_nodes ||= subject.sweep

  def writes = @_writes ||= nodes.select { COUNTED.include?(it.class) }

  def memoized?(name) = lazy?(name) && writes.select { it.name == name }.all? { blank?(it) || guarded?(it) }

  def lazy?(name) = cached.include?(name) || probed.include?(name)

  def probed = @_probed ||= probes(nodes)

  def blank?(write) = write.is_a?(Prism::InstanceVariableWriteNode) && write.value.is_a?(Prism::NilNode)

  def guarded?(write) = guarded.any? { it.equal?(write) }

  def guarded = @_guarded ||= methods.flat_map { shielded(Hashira::Smells::Scope.sweep(it)) }

  def shielded(body)
    probed = probes(body)
    body.select { COUNTED.include?(it.class) && probed.include?(it.name) }
  end

  def cached = @_cached ||= nodes.grep(Prism::InstanceVariableOrWriteNode).map(&:name)

  def probes(body) = body.grep(Prism::DefinedNode).map(&:value).grep(Prism::InstanceVariableReadNode).map(&:name)

  def detail = Sprawl.new(site:, count: names.size, weight:, limit:)

  def evidence = names.map { "#{it}#{given.include?(it) ? GIVEN : NOTES[heft(it)]}" }
end
