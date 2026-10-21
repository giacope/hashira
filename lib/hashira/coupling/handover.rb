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
      @handed.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(host, hosting, given, nesting), found|
        found[exact(given, nesting)] << (exact(host, hosting) || FOREIGN)
      end
  end

  def exact(segments, nesting)
    found = @census.locate(segments, nesting)
    found if found&.last == segments.last
  end
end
