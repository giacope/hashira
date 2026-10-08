# frozen_string_literal: true

module Hashira::Coupling::Stratum
  PRESENTATION = %w[controllers serializers resources].freeze

  module_function

  def presentation?(path) = PRESENTATION.include?(of(path))

  def of(path)
    folders = File.expand_path(path).split("/")
    app = folders[...-2].rindex("app")
    folders[app + 1] if app
  end
end
