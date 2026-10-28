module Shop
  class Missing < Notice
    def title = "USE eager loading"

    def body = "#{key}\n  Add to your query: #{includes}"
  end
end
