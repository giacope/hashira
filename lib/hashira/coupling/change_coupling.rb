# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::ChangeCoupling < Hashira::Coupling::Rule
  KIND = "change_coupling"

  COMMITS = 5

  DEGREE = 50

  FILES = 30

  Pair =
    Data.define(:files, :shared, :revisions) do
      def degree = (200.0 * shared / revisions.sum).round

      def key = files.join(" <-> ")
    end

  Detail =
    Data.define(:files, :packages, :shared, :degree, :explicit) do
      def key = files.join(" <-> ")
    end

  def list
    pairs = together.filter_map { |files, shared| pair(files, shared) }
    pairs.sort_by { [-it.degree, -it.shared, it.key] }.map { entry(it) }
  end

  private

  def pair(files, shared)
    return if shared < limit("commits", COMMITS)
    revisions = @_revisions ||= changesets.flatten.tally
    found = Pair.new(files:, shared:, revisions: files.map { revisions[it] })
    found if found.degree >= limit("degree", DEGREE) && apart?(files) && !registration?(files)
  end

  def registration?(files) = registered?(files) && !explicit?(files.map { sources.fetch(it) })

  def registered?(files)
    manifests =
      @_manifests ||= Hash.new { |found, file| found[file] = Hashira::Coupling::Manifest.new(file, graph.trees.fetch(sources.fetch(file))) }
    [files, files.reverse].any? { |from, to| manifests[from].names?(to) }
  end

  def limit(name, default) = @rules.limit(KIND, name, default)

  def changesets = @_changesets ||= project.history.changesets.map { present(it) }.select { fits?(it) }

  def present(changeset) = changeset.select { sources.key?(it) }

  def fits?(changeset) = changeset.size.between?(1, limit("files", FILES))

  def sources = @_sources ||= graph.trees.keys.to_h { [project.relative(it).b, it] }

  def together
    changesets.each_with_object(Hash.new(0)) do |changeset, counts|
      changeset.sort.combination(2) { counts[it] += 1 }
    end
  end

  def apart?(files)
    files.map { package(it) }.uniq.size == 2
  end

  def package(file) = (@_packages ||= {})[file] ||= graph.home(sources.fetch(file))

  def entry(pair)
    detail = described(pair)
    evidence = detail.files.zip(pair.revisions).map { |file, count| "#{file}: #{count} commits" }
    finding(package: detail.packages.first, digest: detail.key, evidence:, detail:, anchors: anchors(pair))
  end

  def described(pair)
    files = pair.files
    Detail.new(
      files: files.map { shown(it) }, packages: files.map { package(it) }, shared: pair.shared, degree: pair.degree,
      explicit: explicit?(files.map { sources.fetch(it) })
    )
  end

  def shown(file) = file.dup.force_encoding(Encoding::UTF_8)

  def explicit?(files) = [files, files.reverse].any? { links.include?(it) }

  def links
    @_links ||=
      graph.sightings.each_with_object(Set.new) do |sighting, found|
        graph.files(sighting.path).each { found << [sighting.file, it] }
      end
  end

  def anchors(pair)
    pair.files.map do |file|
      first = graph.trees.fetch(sources.fetch(file)).statements.body.first
      "#{shown(file)}:#{first ? first.location.start_line : 1}"
    end
  end
end
