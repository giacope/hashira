module Shop
  class Gate
    def initialize(config)
      @config = config
    end

    def open?(env)
      return false if @config.mode == :closed

      named?(env) || @config.mode == :closed
    end

    private

    def named?(env) = env["QUERY"] =~ /#{@config.parameter}=on/
  end
end
