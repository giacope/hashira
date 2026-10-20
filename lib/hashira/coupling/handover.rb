# frozen_string_literal: true

class Hashira::Coupling::Handover
  FOREIGN = :foreign

  def initialize(handed, census, told)
    @handed = handed
    @census = census
    @told = told
  end

  def hosts(path) = gifts.fetch(path, [])

  def told?(path) = @told.any? { path.last(it.size) == it || it.last(path.size) == path }

  private

  def gifts
    @_gifts ||=
      @handed.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(host, given), found|
        found[@census.locate(given, [])] << ((host && @census.locate(host, [])) || FOREIGN)
      end
  end
end
