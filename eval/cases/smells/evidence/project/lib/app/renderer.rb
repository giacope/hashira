module App
  class Widget
    def html = "<p></p>"
  end

  class Renderer
    def initialize(layout) = @layout = layout

    def render(widget)
      return @layout if widget.nil?
      widget.respond_to?(:html) ? widget.html : @layout.wrap(widget)
    end
  end
end
