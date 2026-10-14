# frozen_string_literal: true

class Hashira::Report::Listing
  def initialize(io)
    @io = io
  end

  def print(title, items)
    return if items.empty?
    @io.puts("\n#{title} (#{items.size}):")
    items.each { |item| @io.puts("  #{yield(item)}") }
  end

  def waived(title, pairs) = print(title, pairs) { |finding, why| "~ #{finding.heading} — #{why}" }
end
