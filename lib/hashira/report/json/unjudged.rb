# frozen_string_literal: true

class Hashira::Report::Json::Unjudged
  def initialize(unjudged)
    @unjudged = unjudged
  end

  def to_h(_cap)
    told = @unjudged.to_a
    told.empty? ? {} : { unjudged: told }
  end

  def lists = {}
end
