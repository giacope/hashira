# frozen_string_literal: true

class Hashira::Smells::BoundarySprawl
  KIND = "boundary_sprawl"

  METHOD_FLOOR = 12

  FILE_FLOOR = 3

  SHOWN = 4

  BUILTINS = Hashira::Runtime::Builtins.new

  class Reach
    def initialize(count, files)
      @count = count
      @files = files
    end

    def to_h = { count: @count, files: @files }

    def phrase(package)
      "#{@count} methods across #{@files} files each pick apart #{package}'s " \
        "internals. Front the boundary with one adapter the rest can lean on."
    end
  end

  def initialize(subjects, interpreted, rules)
    @subjects = subjects
    @interpreted = interpreted
    @rules = rules
  end

  def findings
    foreign.filter_map { |root, contexts| finding(root, contexts) }
  end

  private

  def reaches
    @subjects.each_with_object({}) do |subject, map|
      Hashira::Smells::Foreign.new(subject, subject.ownership).reaches.each { (map[it] ||= []) << subject }
    end
  end

  def foreign = reaches.except(*@interpreted).reject { |root, _| builtin?(root) }

  def builtin?(root) = BUILTINS.core?(root)

  def finding(root, contexts)
    files = contexts.map(&:file).uniq
    return unless wide?(contexts.size, files.size)
    proof = Hashira::Analysis::Finding::Proof.new(contexts.first(SHOWN).map(&:site))
    reach = Reach.new(contexts.size, files.size)
    Hashira::Analysis::Finding.new(KIND, Hashira::Analysis::Finding::Name.new(root), reach, proof)
  end

  def wide?(methods, files) = methods >= @rules.limit(KIND, "threshold", METHOD_FLOOR) && files >= FILE_FLOOR
end
