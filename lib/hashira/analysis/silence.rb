# frozen_string_literal: true

class Hashira::Analysis::Silence
  def initialize(used, rest, starts)
    @used = used
    @rest = rest
    @starts = starts
  end

  def kept(finding) = @used.empty? ? [[finding], [], []] : [[], [[finding, @used.fetch(0)]], @used]

  def trimmed(finding)
    return kept(finding) if @used.empty? || @starts.size < 2
    [[yield(@rest, @starts.fetch(0), @starts.size)], [], @used]
  end
end
