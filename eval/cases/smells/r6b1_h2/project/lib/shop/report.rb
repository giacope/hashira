module Shop
  class Report
    attr_reader :title, :rows, :footer

    def initialize(title, rows, footer)
      @title = title
      @rows = rows
      @footer = footer
    end
  end
end
