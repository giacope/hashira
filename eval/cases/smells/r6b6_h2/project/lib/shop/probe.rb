module Shop
  class Probe
    def initialize(log)
      @log = log
    end

    def computed(object, event, name)
      before = object.send(name)
      done = object.send("#{event}!")
      after = object.send(name)
      @log.record(before, done, after)
    end

    def literal(object, name)
      before = object.send(name)
      done = object.send(:launch!)
      after = object.send(name)
      @log.record(before, done, after)
    end

    def public_computed(object, event)
      before = object.state.to_s
      done = object.public_send(:"#{event}!")
      after = object.state.to_s
      @log.record(before, done, after)
    end

    def opaque(object, event, name)
      before = object.send(name)
      done = object.send(event)
      after = object.send(name)
      @log.record(before, done, after)
    end
  end
end
