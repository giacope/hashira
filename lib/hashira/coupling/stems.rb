# frozen_string_literal: true

class Hashira::Coupling::Stems
  def initialize(prefixes, suffixes)
    @prefixes = prefixes
    @suffixes = suffixes
  end

  def dynamic?(name) = @prefixes.any? { name.start_with?(it) } || @suffixes.any? { name.end_with?(it) }

  def assembled?(path)
    name = path.join("::")
    @prefixes.any? { name.start_with?(it) } || @suffixes.any? { path.last.end_with?(it) }
  end
end
