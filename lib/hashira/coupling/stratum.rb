# frozen_string_literal: true

module Hashira::Coupling::Stratum
  PRESENTATION = %w[controllers serializers resources].freeze

  APP = %w[app].freeze

  module_function

  def presentation?(path) = PRESENTATION.include?(of(path))

  def of(path) = under(path, APP)

  def under(path, roots)
    folders = File.expand_path(path).split("/")
    root = folders[...-2].rindex { roots.include?(it) }
    folders[root + 1] if root
  end
end
