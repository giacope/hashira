module Shop
  class Path
    PATTERN = %r{\A/(?<prefix>[a-z-]+)/(?<slug>[a-z-]+)\z}

    def initialize(text)
      @text = text
    end

    def prefix
      parts = PATTERN.match(@text)
      return "" if parts.nil?

      parts["prefix"]
    end

    def slug
      parts = %r{\A/(?<prefix>[a-z-]+)/(?<slug>[a-z-]+)\z}.match(@text)
      return "" if parts.nil?

      parts["slug"]
    end

    def page
      found = Shop::Pages.find(@text)
      return "" if found.nil?

      found.title
    end
  end

  module Pages
    def self.find(text) = text.empty? ? nil : text
  end
end
