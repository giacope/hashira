# frozen_string_literal: true

require "prism"

class Hashira::Smells::Probe
  PROTOCOLS = %i[
    call close each each_pair flush pos read readpartial rewind seek write
    to_a to_ary to_h to_hash to_i to_int to_io to_json to_model to_param to_path to_proc to_s to_str to_sym to_unsafe_h
  ].freeze

  HELD = [NilClass, Prism::SelfNode, Prism::InstanceVariableReadNode].freeze

  SELVES = [NilClass, Prism::SelfNode].freeze

  LITERAL = [Prism::SymbolNode, Prism::StringNode].freeze

  NAMED = [Prism::LocalVariableReadNode, Prism::InstanceVariableReadNode].freeze

  def initialize(call, subject, foreign)
    @call = call
    @subject = subject
    @foreign = foreign
  end

  def line = @call.location.start_line

  def excused? = asked?(PROTOCOLS) || unspoken? || computed? || foreign? || unknown? || stranger?

  def shown = "#{receiver&.slice || "self"}.respond_to?(#{message&.slice})"

  def trusted? = HELD.include?(receiver.class) || injected?

  private

  def receiver = @call.receiver

  def message = Array(@call.arguments&.arguments).first

  def asked?(names) = message.is_a?(Prism::SymbolNode) && names.include?(Hashira::Analysis::Syntax.new(message).symbol)

  def unspoken? = message.is_a?(Prism::SymbolNode) && !spoken?

  def computed? = !message.nil? && !LITERAL.include?(message.class)

  def spoken? = @subject.ownership.vocabulary.speaks?(Hashira::Analysis::Syntax.new(message).symbol)

  def foreign? = receiver.is_a?(Prism::LocalVariableReadNode) && @foreign.external?(receiver.name)

  def unknown? = !SELVES.include?(receiver.class) && !(named? && typed?)

  def typed? = @foreign.kinds(holder).any?

  def stranger? = named? && LITERAL.include?(message.class) && @foreign.guessed?(holder) && unanswered?

  def unanswered? = @foreign.kinds(holder).none? { answers?(it) }

  def answers?(kind) = @subject.ownership.repertoire.of(kind).include?(Hashira::Analysis::Syntax.new(message).text)

  def named? = NAMED.include?(receiver.class)

  def holder = Hashira::Smells::Refs::Local.new(receiver.slice.delete_prefix("@").to_sym, @subject.node)

  def injected? = receiver.is_a?(Prism::LocalVariableReadNode) && stored.include?(receiver.name)

  def stored = body.grep(Prism::InstanceVariableWriteNode).map(&:value).grep(Prism::LocalVariableReadNode).map(&:name)

  def body = @_body ||= Hashira::Smells::Scope.new(@subject.node).inside
end
