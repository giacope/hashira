# frozen_string_literal: true

class Hashira::Smells::Locals
  def initialize(subject, writes, foreign, words)
    @subject = subject
    @writes = writes
    @foreign = foreign
    @words = words
  end

  def answered?(name, message) = @writes.built?(name) || typed?(name, message)

  private

  def typed?(local, message)
    holder = Hashira::Smells::Refs::Local.new(local, @subject.node)
    @foreign.kinds(holder).any? { @words.of(it).include?(message.to_s.delete_suffix("=")) }
  end
end
