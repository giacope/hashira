# frozen_string_literal: true

require "prism"

class Hashira::Smells::Provenance
  HIDDEN = %i[private protected].freeze

  OPTIONAL = [Prism::OptionalParameterNode, Prism::OptionalKeywordParameterNode].freeze

  WRITES = [Prism::LocalVariableWriteNode, *OPTIONAL].freeze

  REACHED = [Prism::InstanceVariableReadNode, Prism::CallNode].freeze

  def initialize(subject, foreign, rules)
    @subject = subject
    @foreign = foreign
    @rules = rules
  end

  def made?(node, seen = Set.new)
    case node
    when Prism::InstanceVariableReadNode, Prism::NilNode then true
    when Prism::LocalVariableReadNode then seen.add?(node.name) && local?(node.name, seen)
    else node.is_a?(Prism::CallNode) && answered?(node)
    end
  end

  def source(node) = (sourced(node) if strict?)

  def writes = strict? ? WRITES : WRITES.first(1)

  def options(nodes)
    named = nodes.select { optional?(it) }.map { it.name.to_s }.uniq
    named if named.any?
  end

  private

  def strict? = @rules.strict?

  def sourced(node)
    case node
    when Prism::LocalVariableReadNode then sole(@foreign.writes(node.name).map { sourced(it.value) })
    when Prism::CallNode then spring(node)
    end
  end

  def optional?(node) = node.is_a?(Prism::LocalVariableReadNode) && defaulted.include?(node.name)

  def local?(name, seen) = argument?(name) ? handed?(name) : @foreign.writes(name).any? { made?(it.value, seen) }

  def argument?(name) = @subject.parameters.include?(name)

  def handed?(name) = HIDDEN.include?(@subject.section) || defaulted.include?(name)

  def defaulted = @_defaulted ||= strict? ? nils : []

  def nils
    Hashira::Smells::Parameters.new(@subject.node).parts.filter_map do
      it.name if OPTIONAL.include?(it.class) && it.value.is_a?(Prism::NilNode)
    end
  end

  def sole(found) = (found.first if found.any? && found.uniq.one?)

  def spring(call) = ("#{holder(call.receiver)}##{call.name}" if sprung?(call))

  def sprung?(call)
    path = holder(call.receiver)
    path && @subject.ownership.nulls.answer?(path, call.name)
  end

  def holder(receiver)
    case receiver
    when Prism::InstanceVariableReadNode then named(receiver.name.to_s.delete_prefix("@"))
    when Prism::LocalVariableReadNode then sole(kinds(receiver.name))
    when Prism::CallNode then built(receiver)
    end
  end

  def named(name) = sole(Hashira::Smells::Naming.new(name).types.filter_map { place(it) }.first(1) - [@subject.owner])

  def kinds(local) = @foreign.kinds(Hashira::Smells::Refs::Local.new(local, @subject.node)).map { it.join("::") }

  def built(call) = (place(Hashira::Analysis::Syntax.new(call.receiver).segments) if call.name == :new)

  def place(segments) = @subject.ownership.place(segments, @subject.owner)

  def answered?(call)
    receiver = call.receiver
    return own?(call.name) if receiver.nil? || receiver.is_a?(Prism::SelfNode)
    return @subject.ownership.answers?(receiver, @subject.owner) if constant?(receiver)
    reached?(call)
  end

  def reached?(call)
    receiver = call.receiver
    case receiver
    when Prism::LocalVariableReadNode then @foreign.built?(receiver.name) || typed?(receiver.name, call.name)
    when *REACHED then strict? && (sprung?(call) || spoken?(built(receiver), call.name))
    else false
    end
  end

  def spoken?(path, message) = path && @subject.ownership.repertoire.of(path.split("::")).include?(message.to_s)

  def constant?(node) = node.is_a?(Prism::ConstantReadNode) || node.is_a?(Prism::ConstantPathNode)

  def own?(name) = !filled?(name) && (known?(name) || @subject.neighbors.include?(name) || hosted?(name))

  def known?(name) = answers.include?(name.to_s.delete_suffix("="))

  def filled?(name)
    found = Hashira::Analysis::TypeWalk.new(@subject.home).sections.map(&:first).select { it.name == name }
    found.any? && found.all? { settled?(Hashira::Analysis::Syntax.new(it).statements) }
  end

  def settled?(statements)
    tail = statements.last
    value = tail.is_a?(Prism::InstanceVariableOrWriteNode) ? tail.value : tail
    statements.one? && Hashira::Smells::NilCheck::DEFAULTS.include?(value.class)
  end

  def hosted?(name) = @subject.host == :module && @subject.ownership.vocabulary.speaks?(name)

  def answers = @_answers ||= @subject.ownership.repertoire.of(@subject.owner.split("::"))

  def typed?(local, message)
    holder = Hashira::Smells::Refs::Local.new(local, @subject.node)
    @foreign.kinds(holder).any? { @subject.ownership.repertoire.of(it).include?(message.to_s.delete_suffix("=")) }
  end
end
