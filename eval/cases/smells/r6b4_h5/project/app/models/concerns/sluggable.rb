module Sluggable
  refine ::String do
    attr_writer :slug
  end
end
