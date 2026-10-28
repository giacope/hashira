module Shop
  class Page
    def initialize(labels)
      @labels = labels
    end

    def reset
      @index = nil
      @names = nil
    end

    def index
      unless @index
        found = {}
        @labels.each { |label| found[label.key] = label }
        @index = found
      end
      @index
    end

    def names
      if @names.nil?
        @names = @labels.map(&:name)
      else
        @labels.clear
        @names
      end
    end
  end
end
