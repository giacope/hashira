# frozen_string_literal: true

class Hashira::Report::Tabled
  def initialize(kind, subject, page)
    @kind = kind
    @subject = subject
    @page = page
  end

  def print = @page.table(@kind, @subject)
end
