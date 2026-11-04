# frozen_string_literal: true

class Hashira::Judging
  HISTORIC = "change_coupling"

  private_constant :HISTORIC

  def initialize(rules, selection, history)
    @rules = rules
    @selection = selection
    @history = history
  end

  def findings(analyzers, checks = Hashira::Checks.new)
    enabled = checks.select { @rules.enabled?(it) }
    analyzers.findings(churn).select { it.of?(enabled) }
  end

  def analyses(analyzers) = analyzers.analyses(churn)

  def focus(paths) = @selection.focus(paths)

  def history(told, label)
    depth = Hashira::Churn::Depth.build(@history)
    told.churn(label, depth, coupling: @rules.enabled?(HISTORIC)) unless depth.deep?
  end

  private

  def churn = @_churn ||= Hashira::Churn.build(@history)
end
