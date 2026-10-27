# frozen_string_literal: true

module Shop
  class Settings
    attr_writer :base
    attr_accessor :model

    def initialize(model, values = nil)
      @base = nil
      @model = model
      set values
    end

    def use(*mods)
      mods.each { |mod| @model.include(lookup(mod)) unless uses?(mod) }
    end

    def uses?(mod)
      @model < lookup(mod)
    end

    def field
      base.to_s
    end

    def base(*value)
      if value.empty?
        @base
      else
        self.base = value.first
      end
    end

    def lookup(object)
      Module === object ? object : Shop.const_get(object.to_s)
    end

    def set(values)
      values&.each { |name, value| send "#{name}=", value }
    end
  end
end
