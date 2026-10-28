module Shop
  class Stamp
    def initialize(timeout)
      @timeout = timeout
    end

    def label
      deadline = Time.now + @timeout
      [deadline, (Time.now - 60).to_s, (Time.now - 60).to_s]
    end
  end
end
