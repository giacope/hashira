# frozen_string_literal: true

class Hashira::Smells::Speech
  def initialize(subject, words)
    @subject = subject
    @words = words
  end

  def own?(name) = !filled?(name) && (known?(name) || @subject.neighbors.include?(name) || hosted?(name))

  def spoken?(paths, message) = paths.any? { @words.of(it.split("::")).include?(message.to_s) }

  private

  def known?(name) = answers.include?(name.to_s.delete_suffix("="))

  def answers = @_answers ||= @words.of(@subject.owner.split("::"))

  def filled?(name)
    found = Hashira::Analysis::TypeWalk.new(@subject.home).sections.map(&:first).select { it.name == name }
    found.any? && found.all? { settled?(Hashira::Analysis::Syntax::Body.new(it).to_a) }
  end

  def settled?(statements)
    tail = statements.last
    value = tail.is_a?(Prism::InstanceVariableOrWriteNode) ? tail.value : tail
    statements.one? && Hashira::Analysis::Syntax::Value.new(value).default?
  end

  def hosted?(name) = @subject.host == :module && @words.speaks?(name)
end
