# frozen_string_literal: true

class Hashira::Coupling::Code
  def initialize(sightings, reading, ledger)
    @sightings = sightings
    @reading = reading
    @ledger = ledger
  end

  def to_a = @sightings.to_a

  def to_h = @reading.to_h

  def home(file) = @ledger.home(file)

  def files(path) = @ledger.files(path)

  def holder(path) = @ledger.holder(path)

  def unlayered(layers, files) = files.reject { layers.rank(it, home(it)) }
end
