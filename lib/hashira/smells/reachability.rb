# frozen_string_literal: true

class Hashira::Smells::Reachability
  def self.build(subject, every, discards)
    course = Hashira::Smells::Course.new(subject, every, discards)
    new(
      subject.accept(Hashira::Smells::Branches), course, subject.accept(Hashira::Smells::Retries),
      subject.accept(Hashira::Smells::Endings)
    )
  end

  def initialize(branches, course, retries, endings)
    @branches = branches
    @course = course
    @retries = retries
    @endings = endings
  end

  def reachable?(nodes) = nodes.combination(2).any? { |pair| @branches.together?(pair) && !parted?(pair) }

  private

  def parted?(pair) = @endings.parts?(*pair) || @course.disturbed?(pair, @branches) || @retries.retry?(*pair)
end
