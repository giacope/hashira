# frozen_string_literal: true

class Hashira::Smells::Heirs
  KIND = "concrete_inheritance"

  BUILT = :built

  class Kin
    def initialize(site:, places:, parent:, mode:)
      @site = site
      @places = places
      @parent = parent
      @mode = mode
    end

    def to_h
      fields = { site:, places:, parent:, mode: }
      mode == BUILT ? fields.except(:mode) : fields
    end

    private

    attr_reader :site, :places, :parent, :mode
  end

  def initialize(findings)
    @findings = findings
  end

  def findings
    cores, heirs = @findings.select { it.kind == KIND }.partition { it.detail.mode == :core }
    cores + heirs.group_by { it.detail.parent }.map { merged(*it) }
  end

  private

  def merged(parent, group)
    first = group.first
    home = first.detail.home
    Hashira::Analysis::Finding.new(
      kind: KIND, package: parent, detail: kin(home, group, parent),
      evidence: group.map { "#{it.package} (#{it.detail.site})" } + group.flat_map(&:evidence).uniq,
      anchors: [home, *group.flat_map(&:anchors)].uniq, confidence: first.confidence
    )
  end

  def kin(home, group, parent) = Kin.new(site: home, places: group.size, parent:, mode: group.first.detail.mode)
end
