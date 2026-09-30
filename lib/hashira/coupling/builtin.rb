# frozen_string_literal: true

require "rbconfig"

module Hashira::Coupling::Builtin
  SHELVES = RbConfig::CONFIG.values_at("rubylibdir", "rubyarchdir").freeze

  EXTENSIONS = ["", ".rb", ".#{RbConfig::CONFIG["DLEXT"]}"].freeze

  BUNDLED = Gem::BUNDLED_GEMS::SINCE.keys.freeze

  module_function

  def include?(name) = native?(name) || shelved?(name.downcase)

  def native?(name) = Object.const_defined?(name) && !Object.const_source_location(name).first.to_s.end_with?(".rb")

  def shelved?(stem) = BUNDLED.include?(stem) || stocked?(stem)

  def stocked?(stem) = SHELVES.product(EXTENSIONS).any? { |shelf, suffix| File.exist?("#{shelf}/#{stem}#{suffix}") }
end
