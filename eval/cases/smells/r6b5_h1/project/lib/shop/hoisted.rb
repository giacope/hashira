module Shop
  class Hoisted
    def initialize(finder, config)
      @finder = finder
      @config = config
    end

    def scan(children)
      children.each do |child|
        if child.orphan?
          @finder.skip(@config.limit(:orphans))
          next
        end
        @finder.keep(@config.limit(:orphans))
      end
    end
  end
end
