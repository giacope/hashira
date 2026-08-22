# frozen_string_literal: true

class Hashira::Smells::BoundarySprawl
  KIND = "boundary_sprawl"

  METHOD_FLOOR = 12

  FILE_FLOOR = 3

  SHOWN = 4

  def initialize(subjects, ownership)
    @subjects = subjects
    @ownership = ownership
  end

  def findings
    reaches.filter_map { |root, contexts| finding(root, contexts) }
  end

  private

  def reaches
    @subjects.each_with_object({}) do |subject, map|
      Hashira::Smells::Foreign.new(subject, @ownership).reaches.each { (map[it] ||= []) << subject }
    end
  end

  def finding(root, contexts)
    files = contexts.map(&:file).uniq
    build(root, contexts, files) if wide?(contexts.size, files.size)
  end

  def wide?(methods, files) = methods >= METHOD_FLOOR && files >= FILE_FLOOR

  def build(root, contexts, files)
    Hashira::Analysis::Finding.new(
      kind: KIND, package: root, sources: files,
      detail: { count: contexts.size, files: files.size },
      evidence: contexts.first(SHOWN).map(&:site)
    )
  end
end
