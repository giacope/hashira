# frozen_string_literal: true

require "rbconfig"

module Hashira::Coupling::Builtin
  SHELVES = RbConfig::CONFIG.values_at("rubylibdir", "rubyarchdir").freeze

  EXTENSIONS = ["", ".rb", ".#{RbConfig::CONFIG["DLEXT"]}"].freeze

  module_function

  def include?(name) = native?(name) || shelved?(name.downcase)

  def native?(name) = Object.const_defined?(name) && !Object.const_source_location(name).first.to_s.end_with?(".rb")

  def shelved?(stem) = SHELVES.product(EXTENSIONS).any? { |shelf, suffix| File.exist?("#{shelf}/#{stem}#{suffix}") }
end
