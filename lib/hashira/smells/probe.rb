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

  def initialize(call, subject, foreign, words)
    @call = call
    @subject = subject
    @foreign = foreign
    @words = words
  end

  def line = @call.location.start_line

  def excused? = asked?(PROTOCOLS) || unspoken? || computed? || foreign? || unknown? || stranger?

  def shown = "#{receiver&.slice || "self"}.respond_to?(#{messages.map(&:slice).join})"

  def trusted? = HELD.include?(receiver.class) || injected?

  private

  def receiver = @call.receiver

  def messages = Array(@call.arguments&.arguments).first(1)

  def word = Hashira::Analysis::Syntax::Word.new(messages.fetch(0))

  def symbol? = messages.any?(Prism::SymbolNode)

  def asked?(names) = symbol? && names.include?(word.symbol)

  def unspoken? = symbol? && !spoken?

  def computed? = messages.any? { !LITERAL.include?(it.class) }

  def spoken? = @words.speaks?(word.symbol)

  def foreign? = receiver.is_a?(Prism::LocalVariableReadNode) && @foreign.external?(receiver.name)

  def unknown? = !SELVES.include?(receiver.class) && !(named? && typed?)

  def typed? = @foreign.kinds(holder).any?

  def stranger? = named? && messages.any? { LITERAL.include?(it.class) } && @foreign.guessed?(holder) && unanswered?

  def unanswered? = @foreign.kinds(holder).none? { answers?(it) }

  def answers?(kind) = @words.of(kind).include?(word.to_s)

  def named? = NAMED.include?(receiver.class)

  def holder = Hashira::Smells::Refs::Local.new(receiver.slice.delete_prefix("@").to_sym, @subject.node)

  def injected? = receiver.is_a?(Prism::LocalVariableReadNode) && stored.include?(receiver.name)

  def stored = body.grep(Prism::InstanceVariableWriteNode).map(&:value).grep(Prism::LocalVariableReadNode).map(&:name)

  def body = @_body ||= Hashira::Smells::Scope.new(@subject.node).inside
end
