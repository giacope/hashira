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

  private

  def naming = @_naming ||= Hashira::Coupling::Naming.new(@definitions)

  def entries = @_entries ||= @definitions.map { |node, full, folder| entry(node, full, folder) }

  def entry(node, full, folder)
    Hashira::Coupling::Definition.new(node:, path: naming.strip(full), folder:)
  end
end
