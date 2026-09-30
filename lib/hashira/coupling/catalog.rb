# frozen_string_literal: true

class Hashira::Coupling::Catalog
  include Enumerable

  def initialize(definitions)
    @definitions = definitions
  end

  def each(&) = entries.each(&)

  def prefix = naming.segments

  def strip(path) = naming.strip(path)

  def roots = @definitions.roots

  def folders = @definitions.packages

  def lineage = @_lineage ||= Hashira::Coupling::Lineage.new(self)

  def territory = @_territory ||= Hashira::Coupling::Territory.new(self)

  private

  def naming = @_naming ||= Hashira::Coupling::Naming.new(@definitions)

  def entries = @_entries ||= @definitions.map { |node, full, *placing| entry(node, naming.strip(full), *placing) }

  def entry(node, path, folder, scope, file) = Hashira::Coupling::Definition.new(node:, path:, folder:, scope:, file:)
end
