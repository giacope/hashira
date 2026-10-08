# frozen_string_literal: true

require "prism"

class Hashira::Smells::Probe
  PROTOCOLS = %i[
    call close each each_pair flush pos read readpartial rewind seek write
    to_a to_ary to_h to_hash to_i to_int to_io to_json to_model to_param to_path to_proc to_s to_str to_sym to_unsafe_h
  ].freeze

  CORE = [Integer, Float, String, Symbol, Array, Hash, Range].flat_map(&:public_instance_methods).to_set.freeze

  REQUESTS = %i[params request].freeze

  HELD = [NilClass, Prism::SelfNode, Prism::InstanceVariableReadNode].freeze

  def initialize(call, subject, foreign)
    @call = call
    @subject = subject
    @foreign = foreign
  end

  def line = @call.location.start_line

  def excused? = asked?(PROTOCOLS) || disguised? || foreign?

  def doubted? = requested?(receiver, [])

  def trusted? = HELD.include?(receiver.class) || injected?

  private

  def receiver = @call.receiver

  def message = Array(@call.arguments&.arguments).first

  def asked?(names) = message.is_a?(Prism::SymbolNode) && names.include?(message.unescaped.to_sym)

  def disguised? = asked?(CORE) && !@subject.ownership.vocabulary.speaks?(message.unescaped.to_sym)

  def foreign? = receiver.is_a?(Prism::LocalVariableReadNode) && @foreign.external?(receiver.name)

  def requested?(node, seen)
    case node
    when Prism::CallNode then (node.variable_call? && REQUESTS.include?(node.name)) || requested?(node.receiver, seen)
    when Prism::LocalVariableReadNode then traced?(node.name, seen)
    else false
    end
  end

  def traced?(name, seen) = !seen.include?(name) && writes(name).any? { requested?(it.value, seen + [name]) }

  def writes(name) = body.grep(Prism::LocalVariableWriteNode).select { it.name == name }

  def injected? = receiver.is_a?(Prism::LocalVariableReadNode) && stored.include?(receiver.name)

  def stored = body.grep(Prism::InstanceVariableWriteNode).map(&:value).grep(Prism::LocalVariableReadNode).map(&:name)

  def body = @_body ||= Hashira::Smells::Scope.inside(@subject.node)
end
