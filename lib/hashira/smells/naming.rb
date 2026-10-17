# frozen_string_literal: true

module Hashira::Smells::Naming
  module_function

  def types(name)
    words = name.to_s.split("_").reject(&:empty?)
    words.each_index.map { [words.drop(it).map(&:capitalize).join] }.reject { Hashira::Analysis::CORE.include?(it.first) }
  end
end
