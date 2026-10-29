# frozen_string_literal: true

class Hashira::Selection
  def self.build(skip, only, checks = Hashira::Checks.new) = new(checks.analyzers - skip, only)

  def initialize(enabled = Hashira::Checks.new.analyzers, only = [])
    @enabled = enabled
    @only = only
  end

  def enabled?(analyzer) = @enabled.include?(analyzer)

  def focus(paths) = Hashira::Focus.new(paths, @only)

  def trees(listing) = Hashira::Trees.new(listing, @only)

  def pipeline(project, rules, layers) = Hashira::Pipeline.build(project, rules, layers, self)
end
