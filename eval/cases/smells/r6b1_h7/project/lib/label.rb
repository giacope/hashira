class Label
  def initialize(separator)
    @separator = separator
  end

  def text(taxon) = [taxon.title, taxon.content_id].join(@separator)
end
