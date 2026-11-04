# frozen_string_literal: true

class Hashira::Smells::Reaches
  TOP = ""

  private_constant :TOP

  def self.build(trees, ownership, names) = new(names, Hashira::Smells::Exports.new(trees, ownership))

  def initialize(names, exports)
    @names = names
    @exports = exports
  end

  def of(subject)
    sources = scoped(subject).map { |path, within| [@exports.origin(path, within), within] }
    sources.reject { |path, within| @names.place(path, within).any? }.map { |path, _| path.first }.uniq
  end

  private

  def scoped(subject)
    body = subject.accept(Hashira::Smells::Scope).inside
    Hashira::Smells::TypeTests.new(body, @names).of { true }.map { |path, rooted| [path, scope(rooted, subject)] }
  end

  def scope(rooted, subject) = rooted ? TOP : subject.home.to_s
end
