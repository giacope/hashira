module Shop
  class Machine
    def initialize(store)
      @store = store
    end

    def successors
      @successors ||= {}
    end

    def states = @states ||= []

    def parent = @parent ||= @store.find(:parent)

    def remove(from)
      return if successors.nil?

      successors.delete(from)
    end

    def known?(state)
      return false if states.nil?

      states.include?(state)
    end

    def lookup(state)
      return :root if parent.nil?

      parent.fetch(state)
    end
  end
end
