# frozen_string_literal: true

class Hashira::Smells::Piece
  def initialize(names, fields, calls)
    @names = names
    @fields = fields
    @calls = calls
  end

  def merge(other) = Hashira::Smells::Piece.new(@names + other.names, @fields | other.fields, @calls | other.calls)

  def linked?(other)
    @fields.intersect?(other.fields) || @calls.intersect?(other.names) || other.calls.intersect?(@names)
  end

  def kept(names, fields) = [@names.select { names.include?(it) }, @fields.select { fields.include?(it) }]

  protected

  attr_reader :names, :fields, :calls
end
