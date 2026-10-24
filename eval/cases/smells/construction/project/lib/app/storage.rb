module App
  module Core
    def initialize(options = {})
      setup(options)
    end

    def setup(options)
      options.each { |key, value| instance_variable_set("@shop_#{key}", value) }
    end
  end

  class Real
    include Core

    def initialize(options = {})
      super
    end

    def temp_url(path) = "#{path}?key=#{@shop_temp_url_key}"
  end

  class Mock
    include Core

    def initialize(options = {})
      @data = options
    end

    def temp_url(path) = "#{path}?key=#{@shop_temp_url_key}&#{@data}"
  end

  class Stub
    def initialize(options = {})
      @data = options
    end

    def temp_url(path) = "#{path}?key=#{@shop_temp_url_key}&#{@data}"
  end
end
