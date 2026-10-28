module Shop
  class Linker
    def initialize(finder, store, socket)
      @finder = finder
      @store = store
      @socket = socket
    end

    def connect(children, orphaned)
      children.each do |child|
        parent = @finder.parent_of(child)
        orphaned << child.slug && next if parent.nil?

        record = @finder.record(parent.slug)
        orphaned << child.slug && next if record.nil?

        record.adopt(child)
      end
    end

    def skipped(children)
      children.each do |child|
        if child.orphan?
          @finder.skip(child.parent.slug)
          next
        end
        @finder.keep(child.parent.slug)
      end
    end

    def returned(child)
      if child.orphan?
        @finder.skip(child.parent.slug)
        return
      end
      @finder.keep(child.parent.slug)
    end

    def create(attrs)
      raise ArgumentError, "no gss for #{@store.name_of(attrs)}" if attrs.empty?

      @store.put(@store.name_of(attrs))
    end

    def read(size, sink)
      while size > 0
        chunk = @socket.read(size) || raise(EOFError)
        size -= sink.write(chunk)
      end
      @socket.read(2) || raise(EOFError)
    end
  end
end
