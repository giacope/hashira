# frozen_string_literal: true

require "digest"

class Hashira::Duplication::Fragment
  DIGEST_LENGTH = 12

  def initialize(file, roots)
    @file = file
    @roots = roots
  end

  attr_reader :file

  def types = @_types ||= nodes.map(&:type)

  def digest = Digest::SHA256.hexdigest(shape).slice(0, DIGEST_LENGTH)

  def shape = types.join(",")

  def mass = types.size

  def line = @roots.first.location.start_line

  def finish = @roots.last.location.end_line

  def location = "#{file}:#{line}"

  def range = "#{file}:#{line}-#{finish}"

  def rank = [file, line]

  def overlaps?(other) = file == other.file && line <= other.finish && other.line <= finish

  def touches?(others) = others.any? { overlaps?(it) }

  def nodes = @_nodes ||= @roots.flat_map { Hashira::Analysis::NodeWalk.collect(it) }
end
