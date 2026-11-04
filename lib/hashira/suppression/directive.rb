# frozen_string_literal: true

class Hashira::Suppression::Directive
  def initialize(site, anchor, kinds, reason)
    @site = site
    @anchor = anchor
    @kinds = kinds
    @reason = reason
  end

  def covers?(kind, anchor) = @kinds.include?(kind) && anchor == @anchor

  def said = "#{@reason} (#{@site})"

  def to_s = "#{@kinds.join(",")} at #{@site}"

  def to_h = { "site" => @site, "kinds" => @kinds, "reason" => @reason }
end
