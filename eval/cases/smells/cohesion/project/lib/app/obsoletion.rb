module App
  class Obsoletion
    def initialize(config)
      @config = config
      @rules = load_rules
      @warnings = []
    end

    def reject_obsolete!
      messages = @rules.filter_map { |rule| rule.violated?(@config) }
      @warnings.concat(messages.select(&:warning?))
      raise ArgumentError, messages.join("\n") unless messages.empty?
    end

    def warnings = @warnings

    def warn(text) = @warnings << text

    private

    def load_rules = load_cop_rules + load_parameter_rules

    def load_cop_rules = @config.fetch(:cops, [])

    def load_parameter_rules = @config.fetch(:parameters, [])
  end

  class ApplicationController < ActionController::Base
  end

  class OrdersController < ApplicationController
    def index
      @orders = Order.all
      @count = @orders.size
    end

    def show
      @order = Order.find(1)
      @lines = @order.lines
    end

    def new = @draft = Order.new

    def edit = @draft = @order

    def summary = @orders.map(&:id)

    def preview = @draft.lines
  end
end
