class Taxon
  attr_accessor :title
  attr_writer :content_id

  def content_id = @content_id || title
end
