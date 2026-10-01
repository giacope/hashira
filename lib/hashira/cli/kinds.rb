# frozen_string_literal: true

class Hashira::CLI::Kinds
  def initialize(flag)
    @flag = flag
  end

  def parse(list)
    return [] if list.to_s.empty?
    kinds = list.split(",").flat_map { Array(kind(it.strip)) }.uniq
    raise(Hashira::Error, "#{@flag} needs at least one kind") if kinds.empty?
    kinds
  end

  private

  def names = Hashira::CLI::FailOn::KINDS

  def kind(name) = names.fetch(name) { raise(Hashira::CLI::Choice.unknown(@flag, name, names.keys)) }
end
