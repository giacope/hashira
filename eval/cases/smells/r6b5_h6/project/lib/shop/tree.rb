module Shop
  class Tree
    def initialize(root)
      @root = root
    end

    def walk(path)
      path = path.dup
      node = @root
      while path.size > 0
        step = path.shift
        child = node.child(step)
        node = child if path.size > 0
      end
      node
    end

    def finish(job)
      before = job.status(:now)
      done = job.finalize!
      [before, done, job.status(:now)]
    end

    def asked(path)
      node = @root
      while path.size > 0
        step = path.first
        node = node.child(step) if path.size > 0
      end
      node
    end
  end
end
