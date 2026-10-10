module App
  class Session
    def initialize(user, store, clock, log)
      @user = user
      @store = store
      @clock = clock
      @log = log
    end

    def open = @token = @store.issue(@user, @clock.now)

    def close
      @store.revoke(@token)
      @log.write(@user)
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
