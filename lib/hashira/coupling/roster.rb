# frozen_string_literal: true

class Hashira::Coupling::Roster
  def initialize(placed)
    @placed = placed
  end

  def registry = @_registry ||= registered

  def types = @_types ||= counted.each_with_object(Hash.new(0)) { |(_, package), counts| counts[package] += 1 }

  def origins = registry.origins

  def type?(path) = typed.include?(path)

  def packages = types.keys | registry.packages

  private

  def packaged = @_packaged ||= @placed.select { |_, package| package }

  def registered
    Hashira::Coupling::ConstantRegistry.new.tap do |registry|
      packaged.each { |definition, package| registry.register(definition.path, package) }
    end
  end

  def counted = packaged.select { |definition, _| definition.counted? }.uniq { |definition, _| definition.path }

  def typed = @_typed ||= packaged.filter_map { |definition, _| definition.path if definition.type? }.to_set
end
