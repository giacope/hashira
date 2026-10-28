module Shop
  class Meter
    def initialize(scanner)
      @scanner = scanner
    end

    def span
      start = @scanner.pos
      finished?
      middle = @scanner.pos
      finished?
      [start, middle, @scanner.pos]
    end

    private

    def finished? = @scanner.eos?
  end
end
