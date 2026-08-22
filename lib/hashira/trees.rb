# frozen_string_literal: true

require "prism"

class Hashira::Trees
  def initialize(snapshot)
    @snapshot = snapshot
  end

  def all = @_all ||= @snapshot.sources.to_h { |path, source| [path, parse(path, source)] }

  def unparsed
    all
    @_unparsed ||= []
  end

  private

  def parse(path, source)
    result = Prism.parse(source, filepath: path)
    (@_unparsed ||= []) << path if result.failure?
    result.value
  end
end
