module Shop
  class Plain
    attr_accessor :notifier, :url

    def initialize(klass, items)
      @klass = klass
      @items = items
    end

    def title
      raise NoMethodError, "no method title defined"
    end

    def body
      raise NoMethodError, "no method body defined"
    end

    def notify = notifier.push(data)

    def data = { url:, title:, body: }

    def short = [url, title, body].join(" ")

    def eql?(other) = other.class == self.class && key == other.key

    def hash = key.hash

    protected

    def key = "#{@klass} => #{@items.join(", ")}"

    def includes = ".includes(#{@items.inspect})"
  end
end
