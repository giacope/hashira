# frozen_string_literal: true

class Hashira::Report::Json::Cap
  def initialize(top)
    @top = top
  end

  def call(list) = @top ? list.first(@top) : list

  def withheld(lists) = @top ? { withheld: lists.transform_values { [it.size - @top, 0].max } } : {}
end
