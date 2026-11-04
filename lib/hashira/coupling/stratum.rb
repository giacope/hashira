# frozen_string_literal: true

class Hashira::Coupling::Stratum
  PRESENTATION = %w[controllers serializers resources].freeze

  APP = %w[app].freeze

  def initialize(path)
    @path = path
  end

  def presentation? = within?(PRESENTATION)

  def within?(strata)
    folders = File.expand_path(@path).split("/")
    root = folders[...-2].rindex { APP.include?(it) }
    root ? strata.include?(folders.fetch(root + 1)) : false
  end
end
