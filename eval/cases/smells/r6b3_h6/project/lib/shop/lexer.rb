require "strscan"

module Shop
  class Lexer
    def initialize(text)
      @scanner = StringScanner.new(text)
    end

    def via_helper
      start = @scanner.pos
      word
      middle = @scanner.pos
      word
      [start, middle, @scanner.pos]
    end

    def direct
      start = @scanner.pos
      @scanner.scan(/\w+/)
      middle = @scanner.pos
      @scanner.scan(/\w+/)
      [start, middle, @scanner.pos]
    end

    private

    def word = @scanner.scan(/\w+/)
  end
end
