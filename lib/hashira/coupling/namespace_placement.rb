# frozen_string_literal: true

require_relative "placement"

class Hashira::Coupling::NamespacePlacement < Hashira::Coupling::Placement
  RAILS_BASES =
    %w[ApplicationRecord ApplicationController ApplicationJob ApplicationMailer
      ApplicationHelper ApplicationCable ApplicationResource ApplicationSerializer
      ApplicationPolicy ApplicationDecorator].freeze

  WEB = "(web)"

  def mode = :namespace

  def placed = catalog.map { [it, home(it)] }

  def baseline = []

  def charge(file, nesting) = served?(file) ? WEB : owner(nesting)

  def skip?(segments) = project.rails? && RAILS_BASES.include?(segments.first)

  def web?(package) = package == WEB

  def folding(census) = Hashira::Coupling::Folding.new(domain, census, suffixes: suffixes)

  private

  def owner(nesting)
    nesting.reverse_each.filter_map { catalog.strip(it).first }.find { names.include?(it) } || project.root
  end

  def home(definition)
    return definition.name unless served?(definition.file)
    WEB unless claimed.include?(definition.path)
  end

  def domain = @_domain ||= catalog.reject { served?(it.file) }

  def names = @_names ||= domain.to_set(&:name)

  def claimed = @_claimed ||= domain.to_set(&:path)

  def served?(file) = project.rails? && Hashira::Coupling::Stratum.presentation?(file)

  def suffixes = project.rails? ? Hashira::Coupling::Folding::SUFFIXES : []
end
