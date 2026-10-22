# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::Echo < Hashira::Coupling::Rule
  KIND = "roll_call"

  REST_ACTIONS = %w[index show new create edit update destroy].to_set.freeze

  def list = rolls.reject { framework?(it) }.map { entry(it) }

  private

  def rolls = Hashira::Coupling::RollCall.new(lists, homes).rolls

  def framework?(roll) = project.rails? && REST_ACTIONS.superset?(roll.words.to_set)

  def sightings
    @_sightings ||=
      graph.trees.filter_map do |file, tree|
        words = Hashira::Coupling::Words.new(tree).lists
        [project.relative(file), graph.home(file), words] unless words.empty?
      end
  end

  def lists = sightings.to_h { |file, _home, words| [file, words] }

  def homes = sightings.to_h { |file, home, _words| [file, home] }

  def entry(roll)
    words, files, packages, sites = roll.deconstruct
    finding(package: packages.first, digest: words.join(","), evidence: sites, detail: { words:, files:, packages: })
  end
end
