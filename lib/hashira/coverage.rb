# frozen_string_literal: true

class Hashira::Coverage
  HISTORIC = "change_coupling"

  private_constant :HISTORIC

  def initialize(rules, selection, history, paths)
    @rules = rules
    @selection = selection
    @history = history
    @paths = paths
  end

  def checked(sieve) = asked(sieve) { checks?(it) }

  def unjudged(sieve)
    left = asked(sieve) { @rules.enabled?(it) && !checks?(it) }
    Hashira::Report::View::Unjudged.new(kinds: left, history: depth, judged: checked(sieve).any?)
  end

  def recorded(home, checks = Hashira::Checks.new)
    yield(checks.analyzers.select { @selection.enabled?(it) }, @paths.to_a.map { home.relative(it) })
  end

  private

  def checks?(kind) = @rules.enabled?(kind) && (kind != HISTORIC || depth.deep?)

  def depth = @_depth ||= Hashira::Churn::Depth.build(@history)

  def asked(sieve, checks = Hashira::Checks.new)
    checks.select { yield(it) && @selection.enabled?(checks.owner(it)) && sieve.keeps?(it) }
  end
end
