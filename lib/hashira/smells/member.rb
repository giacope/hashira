# frozen_string_literal: true

class Hashira::Smells::Member
  SECTIONS = %i[chain source core heir bequest repeat].freeze

  def initialize(section, key, parts, testimony)
    @section = section
    @key = key
    @parts = parts
    @testimony = testimony
  end

  def gather(groups) = groups.merge([SECTIONS.index(@section), @key] => self) { |_key, held, added| held + added }

  def +(other) = Hashira::Smells::Member.new(@section, @key, @parts + other.parts, @testimony + other.testimony)

  def finding = @parts.fetch(0).finding(@parts, @testimony)

  protected

  attr_reader :parts, :testimony
end
