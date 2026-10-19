module App
  class Flow
    def edited_meanwhile(to:) = meanwhile("jz@example.com", "JZ") { edit_message(:third, to:) }
    def boosted_meanwhile(with:) = meanwhile("david@example.com", "David") { boost(:third, with:) }

    private

    def meanwhile(email, name, &) = using_session(email, name, &)
  end
end
