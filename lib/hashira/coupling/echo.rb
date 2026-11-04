# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::Echo < Hashira::Coupling::Rule
  KIND = "roll_call"

  REST_ACTIONS = %w[index show new create edit update destroy].to_set.freeze

  def list = Hashira::Coupling::RollCall.new(lists, homes).rolls.reject { framework?(it) }.map { it.finding(KIND) }

  private

  def framework?(roll) = framework.rails? && roll.within?(REST_ACTIONS)

  def framework = @_framework ||= project.framework

  def sightings
    @_sightings ||=
      code.to_h.filter_map do |file, tree|
        words = Hashira::Coupling::Words.new(tree).lists
        [paths.relative(file), code.home(file), words] unless words.empty?
      end
  end

  def lists = sightings.to_h { |file, _home, words| [file, words] }

  def homes = sightings.to_h { |file, home, _words| [file, home] }
end
