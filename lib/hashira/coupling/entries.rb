# frozen_string_literal: true

class Hashira::Coupling::Entries
  include Enumerable

  def initialize(definitions, naming)
    @definitions = definitions
    @naming = naming
  end

  def each(&) = listed.each(&)

  private

  def listed
    @_listed ||=
      @definitions.map do |node, full, nesting, file|
        Hashira::Coupling::Definition.new(node, @naming.strip(full), nesting, file)
      end
  end
end
