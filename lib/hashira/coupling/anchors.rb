# frozen_string_literal: true

require_relative "contracts"

class Hashira::Coupling::Anchors
  include Hashira::Coupling::Contracts

  def initialize(roots, project)
    @roots = roots
    @project = project
  end

  def rooted?(name, file, open) = declared?(name, file) || entry?(file) || api?(file, open)

  def entry?(file) = framework.rails? && Hashira::Coupling::Stratum.new(absolute(file)).within?(ENTRIES)

  private

  def paths = @_paths ||= @project.paths

  def framework = @_framework ||= @project.framework

  def listing = @_listing ||= @project.listing

  def declared?(name, file) = @roots.any? { root?(it, name, file) }

  def root?(root, name, file)
    return within?(file, root) if root.include?("/") || root.end_with?(".rb")
    name == root || %w[:: # .].any? { name.start_with?("#{root}#{it}") }
  end

  def within?(file, root)
    place = paths.expand(root)
    path = absolute(file)
    path == place || path.start_with?("#{place}/")
  end

  def absolute(file) = listing.located(file)

  def api?(file, open) = (library? || engine_library?(file)) && open

  def library? = !framework.rails? && @roots.empty?

  def engine_library?(file) = framework.engine.any? && @roots.empty? && shipped?(file)

  def shipped?(file) = absolute(file).delete_prefix("#{paths.expand(".")}/").start_with?("lib/")
end
