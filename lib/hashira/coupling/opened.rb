# frozen_string_literal: true

class Hashira::Coupling::Opened
  def initialize(entries, definitions, naming)
    @entries = entries
    @definitions = definitions
    @naming = naming
  end

  def include?(root) = roots.include?(root)

  private

  def roots
    @_roots ||=
      [*@entries.flat_map { it.kin.opened }, *@definitions.implied, @naming.to_a.first(1)]
        .select(&:one?).to_set(&:first)
  end
end
