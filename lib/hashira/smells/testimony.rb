# frozen_string_literal: true

class Hashira::Smells::Testimony
  def initialize(lines, extra, anchors, ratings)
    @lines = lines
    @extra = extra
    @anchors = anchors
    @ratings = ratings
  end

  def +(other)
    Hashira::Smells::Testimony.new(
      @lines + other.lines, @extra + other.extra, @anchors + other.anchors, @ratings & other.ratings
    )
  end

  def proof(ratings = @ratings)
    Hashira::Analysis::Finding::Proof.new(@lines + @extra.uniq, @anchors.uniq, [], ratings)
  end

  def finding(kind, package, detail, ratings = @ratings)
    Hashira::Analysis::Finding.new(kind, Hashira::Analysis::Finding::Name.new(package), detail, proof(ratings))
  end

  protected

  attr_reader :lines, :extra, :anchors, :ratings
end
