# frozen_string_literal: true

class Hashira::Smells::Patrons
  def initialize(foreign, refs, words)
    @foreign = foreign
    @refs = refs
    @words = words
  end

  def of(holder) = @foreign.kinds(holder).select { serves?(it, holder) }

  def dismiss?(holder) = @foreign.dismiss?(holder)

  private

  def serves?(type, holder) = asked(holder, type).subset?(@words.of(type))

  def asked(holder, type)
    seen = @words.closed?(type) ? @refs.sends(holder) : @refs.reads(holder)
    seen.to_set { it.name.to_s.delete_suffix("=") }
  end
end
