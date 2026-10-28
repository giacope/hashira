module Shop
  class Presenter
    attr_reader :guide

    def initialize(guide)
      @guide = guide
    end

    def payload
      { base_path: guide.slug, routes: [{ path: guide.slug }] }
    end

    def computed
      { base_path: current.slug, routes: [{ path: current.slug }] }
    end

    def current = Guide.find(@guide)
  end
end
