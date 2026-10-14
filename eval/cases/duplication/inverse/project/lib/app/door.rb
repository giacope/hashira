module App
  class Door
    def lock!(user)
      raise(Denied, user.name) unless user.keys.include?(@key)
      @state.update(locked: true, by: user.id, at: @clock.now)
      @log.write(:locked, user.id)
    end

    def unlock!(user)
      raise(Denied, user.name) unless user.keys.include?(@key)
      @state.update(locked: false, by: user.id, at: @clock.now)
      @log.write(:unlocked, user.id)
    end
  end
end
