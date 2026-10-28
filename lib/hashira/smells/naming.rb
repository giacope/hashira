# frozen_string_literal: true

class Hashira::Smells::Naming
  def initialize(name, builtins = Hashira::Runtime::Builtins.new)
    @name = name
    @builtins = builtins
  end

  def types
    words = @name.to_s.split("_").reject(&:empty?)
    words.each_index.map { [words.drop(it).map(&:capitalize).join] }.reject { @builtins.core?(it.first) }
  end
end
