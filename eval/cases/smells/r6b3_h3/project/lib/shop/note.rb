module Shop
  class Note
    def body
      raise ArgumentError
    end

    def title = "note"
  end

  class Memo < Note
    def body = "memo"
  end

  class Pad
    def blank = Note.new.title
  end
end
