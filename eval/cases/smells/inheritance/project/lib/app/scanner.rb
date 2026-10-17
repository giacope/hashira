module App
  class Scanner
    KEYS_URI = "https://example.com/keys"

    def initialize(cache)
      @cache = cache
    end

    def keys = @cache.fetch(self.class::KEYS_URI) { download }

    def verify(signature) = keys.include?(signature)

    private

    def download = []
  end

  class DepsDevScanner < Scanner
    KEYS_URI = "https://deps.dev/keys"
  end

  class ScansController
    def create(cache, signature) = Scanner.new(cache).verify(signature)
  end
end
