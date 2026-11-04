# frozen_string_literal: true

class Hashira::Coupling::Exposure
  def initialize(constants)
    @constants = constants
  end

  def exposed?(path) = exposure.fetch(path, true)

  private

  def exposure = @_exposure ||= @constants.each_with_object({}) { |constant, found| found.update(constant.to_h) }
end
