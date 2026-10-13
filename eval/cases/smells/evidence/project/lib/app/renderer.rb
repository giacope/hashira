module App
  class Widget
    def html = "<p></p>"
  end

  class Renderer
    def initialize(layout, widgets)
      @layout = layout
      @widgets = widgets
    end

    def render(name)
      widget = lookup(name)
      return @layout if widget.nil?
      widget.respond_to?(:html) ? widget.html : @layout.wrap(widget)
    end

    private

    def lookup(name) = @widgets.find { it.name == name }
  end
end
