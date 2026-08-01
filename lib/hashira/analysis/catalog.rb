# frozen_string_literal: true

class Hashira::Analysis::Catalog
  include Enumerable

  def initialize(definitions)
    @definitions = definitions
    @naming = Hashira::Analysis::Naming.new(definitions)
    @entries = definitions.map { |node, full, folder| entry(node, full, folder) }
  end

  def each(&) = @entries.each(&)

  def prefix = @naming.segments

  def strip(path) = @naming.strip(path)

  def roots = @definitions.roots

  def folders = @definitions.packages

  private

  def entry(node, full, folder)
    Hashira::Analysis::Definition.new(node:, path: @naming.strip(full), folder:)
  end
end
