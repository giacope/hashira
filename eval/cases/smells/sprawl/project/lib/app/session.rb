module App
  class Session
    def initialize(user, store, clock, log)
      @user = user
      @store = store
      @started = clock.now
      @log = Log.new(log)
    end

    def open = @token = @store.issue(@user, @started)

    def renew = @renewed = @store.renew(@token)

    def close
      @store.revoke(@token)
      @log.write(@user, @renewed)
    end
  end

  class Point
    def initialize(x, y, z, w)
      @x = x
      @y = y
      @z = z
      @w = w
    end

    def norm = Math.sqrt((@x**2) + (@y**2) + (@z**2) + (@w**2))
  end
end
