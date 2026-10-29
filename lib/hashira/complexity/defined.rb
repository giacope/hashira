# frozen_string_literal: true

class Hashira::Complexity::Defined
  def initialize(call)
    @call = call
  end

  def name
    named.respond_to?(:unescaped) ? Hashira::Analysis::Syntax::Word.new(named).symbol : :"define_method(#{named.slice})"
  end

  def body = @call.block.body

  def location = @call.location

  private

  def named = @call.arguments.arguments.fetch(0)
end
