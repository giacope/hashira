# frozen_string_literal: true

class Hashira::Coupling::Stratum
  PRESENTATION = %w[controllers serializers resources].freeze

  APP = %w[app].freeze

  def initialize(path)
    @path = path
  end

  def presentation? = PRESENTATION.include?(of)

  def of
    folders = File.expand_path(@path).split("/")
    root = folders[...-2].rindex { APP.include?(it) }
    folders[root + 1] if root
  end
end
