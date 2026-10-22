# frozen_string_literal: true

class Hashira::Smells::BoundarySprawl
  KIND = "boundary_sprawl"

  METHOD_FLOOR = 12

  FILE_FLOOR = 3

  SHOWN = 4

  def initialize(subjects, ownership, interpreted, rules)
    @subjects = subjects
    @ownership = ownership
    @interpreted = interpreted
    @rules = rules
  end

  def findings
    foreign.filter_map { |root, contexts| finding(root, contexts) }
  end

  private

  def reaches
    @subjects.each_with_object({}) do |subject, map|
      Hashira::Smells::Foreign.new(subject, @ownership).reaches.each { (map[it] ||= []) << subject }
    end
  end

  def foreign = reaches.except(*@interpreted).reject { |root, _| builtin?(root) }

  def builtin?(root) = Hashira::Analysis::CORE.include?(root)

  def finding(root, contexts)
    files = contexts.map(&:file).uniq
    return unless wide?(contexts.size, files.size)
    Hashira::Analysis::Finding.new(
      kind: KIND, package: root,
      detail: { count: contexts.size, files: files.size },
      evidence: contexts.first(SHOWN).map(&:site)
    )
  end

  def wide?(methods, files) = methods >= @rules.threshold(KIND, METHOD_FLOOR) && files >= FILE_FLOOR
end
