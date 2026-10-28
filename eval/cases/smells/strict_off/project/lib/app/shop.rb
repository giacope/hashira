module App
  class Price
    def initialize(cents)
      @cents = cents
    end

    def discounted(coupon = nil)
      return @cents if coupon.nil?
      @cents - coupon.cents
    end
  end

  class Catalog
    def initialize(items)
      @items = items
    end

    def find(code) = @items.detect { it.code == code }

    def fetch(code) = @items.fetch(code)
  end

  class Cart
    def initialize(catalog, codes)
      @catalog = catalog
      @codes = codes
    end

    def total
      @codes.sum do |code|
        item = @catalog.find(code)
        item.nil? ? 0 : item.price
      end
    end

    def sure = @catalog.fetch(@codes.first).nil?
  end

  class Finder
    def initialize(rows)
      @rows = rows
    end

    def parent(id)
      return unless @rows.key?(id)
      @rows.fetch(id)
    end
  end

  class Unpublisher
    def initialize(rows)
      @rows = rows
    end

    def held(id)
      parent = App::Finder.new(@rows).parent(id)
      return false if parent.nil?
      parent.live?
    end
  end

  class Signup
    def initialize(email, referral)
      @email = email
      @referral = referral
    end

    def welcome = "Welcome, #{@email}#{@referral.mention}"
  end
end
