require "forwardable"

module App
  class Session
    def initialize(store)
      @store = store
    end

    def [](key) = @store.get(key)

    def []=(key, value)
      @store.set(key, value)
    end

    def clear = @store.flush

    def expired?(clock) = clock.now > @store.get(:expires_at)
  end

  class Config
    extend Forwardable

    def_delegators :@hash, :fetch, :key?

    def initialize(hash)
      @hash = hash
    end

    def read(key) = @hash.lookup(key)

    def write(key, value) = @hash.store(key, value)

    def reload = @hash.load
  end

  class Bag
    def initialize = @items = []

    def each(&) = @items.each(&)

    def size = @items.size

    def empty? = @items.empty?

    def add(item) = @items.push(item)
  end

  class Shop
    def initialize(cart, payments, mailer)
      @cart = cart
      @payments = payments
      @mailer = mailer
    end

    def add(item) = @cart.add(item)

    def pay(card) = @payments.charge(card)

    def receipt(address) = @mailer.receipt(address)
  end

  class Tally
    def initialize = (@mutex = Mutex.new; @count = 0; @items = [])

    def add = @mutex.synchronize { @count += 1 }

    def count = @mutex.synchronize { @count }

    def items = @mutex.synchronize { @items.dup }
  end

  class Urgent
    def initialize(origin)
      @origin = origin
    end

    def subject = "URGENT: #{@origin.subject}"

    def body = @origin.body

    def recipient = @origin.recipient

    def to_s = @origin.to_s
  end
end
