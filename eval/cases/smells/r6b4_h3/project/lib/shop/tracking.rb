module Shop
  module Tracking
    def initialize(*)
      super
      @events = []
    end

    def track(event)
      @events << event
    end
  end
end
