# frozen_string_literal: true

class Hashira::Smells::Naming
  def initialize(name)
    @name = name
  end

  def types
    words = @name.to_s.split("_").reject(&:empty?)
    words.each_index.map { [words.drop(it).map(&:capitalize).join] }.reject { Hashira::Analysis::CORE.include?(it.first) }
  end
end
