# frozen_string_literal: true

class Hashira::Plan
  COUPLING = :coupling

  def initialize(layers, history, selection)
    @layers = layers
    @history = history
    @selection = selection
  end

  def enabled?(analyzer) = @selection.enabled?(analyzer)

  def unlayered(files) = @layers.names.any? && enabled?(COUPLING) ? yield.unlayered(@layers, files) : []

  def layered = yield(@layers)

  def traced = yield(@history)
end
