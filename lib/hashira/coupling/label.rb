# frozen_string_literal: true

class Hashira::Coupling::Label
  def initialize(name, file, line)
    @name = name
    @file = file
    @line = line
  end

  def to_s = @name

  def <=>(other) = order <=> other.order

  def place = [@file, @line]

  def finding(kind, noun)
    site = "#{@file}:#{@line}"
    proof = Hashira::Analysis::Finding::Proof.new([], [site])
    Hashira::Analysis::Finding.new(
      kind, Hashira::Analysis::Finding::Name.new(@name), Hashira::Coupling::Unused.new(site, noun), proof
    )
  end

  def rooted?(anchors, open) = anchors.rooted?(@name, @file, open)

  protected

  def order = [@file, @line.to_s]
end
