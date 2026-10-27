# frozen_string_literal: true

require "yaml"

module Hashira
  module Analysis
    SHIPPED = YAML.load_file(File.join(__dir__, "inventory.yml")).freeze

    UNIVERSAL = SHIPPED.fetch("universal").to_set(&:to_sym).freeze

    VALUES = SHIPPED.fetch("values").to_set(&:to_sym).freeze

    MACROS = SHIPPED.fetch("macros").to_set(&:to_sym).freeze

    KERNEL = SHIPPED.fetch("kernel").to_set(&:to_sym).freeze

    CORE = SHIPPED.fetch("constants").to_set.freeze

    LIBRARIES = SHIPPED.fetch("libraries").to_set.freeze

    INHERITED = SHIPPED.fetch("inherited").transform_values { it.to_set(&:to_sym).freeze }.freeze
  end
end
