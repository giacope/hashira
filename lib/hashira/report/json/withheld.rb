# frozen_string_literal: true

class Hashira::Report::Json::Withheld
  def initialize(listed)
    @listed = listed
  end

  def to_h(cap) = cap.withheld(@listed.map(&:lists).reduce({}, :merge))

  def lists = {}
end
