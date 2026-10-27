module Shop
  class Tag
    def initialize(lists)
      @lists = lists
    end

    def curated?
      if @curated.nil?
        @curated = @lists.any?
      else
        @curated
      end
    end

    def listed?
      @listed = @lists.any? if @listed.nil?
      @listed
    end

    def sized?
      return @sized unless @sized.nil?

      @sized = @lists.size > 2
    end
  end
end
