# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::RollCallFindings < Hashira::Coupling::Rule
  KIND = "roll_call"

  def list = rolls.map { entry(it) }

  private

  def rolls = Hashira::Coupling::RollCall.new(lists, homes).rolls

  def sightings
    @sightings ||=
      graph.trees.filter_map do |file, tree|
        words = Hashira::Coupling::Words.list(tree)
        [project.relative(file), graph.charge(file), words] unless words.empty?
      end
  end

  def lists = sightings.to_h { |file, _home, words| [file, words] }

  def homes = sightings.to_h { |file, home, _words| [file, home] }

  def entry(roll)
    words, files, packages = roll.deconstruct
    finding(package: packages.first, digest: words.join(","), evidence: files, detail: { words:, files:, packages: })
  end
end
