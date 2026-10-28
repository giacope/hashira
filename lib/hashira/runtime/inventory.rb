# frozen_string_literal: true

require "yaml"

class Hashira::Runtime::Inventory
  SHIPPED = YAML.load_file(File.join(__dir__, "inventory.yml")).freeze

  private_constant :SHIPPED

  def initialize(shipped = SHIPPED)
    @shipped = shipped
  end

  def messages(section) = @shipped.fetch(section).to_set(&:to_sym).freeze

  def words(section) = @shipped.fetch(section).to_set.freeze

  def heritage = @shipped.fetch("inherited").transform_values { it.to_set(&:to_sym).freeze }.freeze
end
