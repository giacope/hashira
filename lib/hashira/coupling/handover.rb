# frozen_string_literal: true

class Hashira::Coupling::Handover
  def initialize(handed, census, told, foreign = :foreign)
    @handed = handed
    @census = census
    @told = told
    @foreign = foreign
  end

  def hosts(path) = gifts.fetch(path, [])

  def told?(path) = @told.any? { path.last(it.size) == it || it.last(path.size) == path }

  def foreign?(host) = host == @foreign

  private

  def gifts
    @_gifts ||=
      @handed.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(host, hosting, given, nesting), found|
        targets = exact(given, nesting)
        holder = exact(host, hosting).fetch(0, @foreign)
        targets.each { found[it] << holder }
      end
  end

  def exact(segments, nesting)
    found = @census.locate(segments, nesting)
    found && found.last == segments.last ? [found] : []
  end
end
