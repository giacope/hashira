# frozen_string_literal: true

require_relative "contracts"

class Hashira::Coupling::Constant
  include Hashira::Coupling::Contracts

  def initialize(label, path, exposed)
    @label = label
    @path = path
    @exposed = exposed
  end

  def to_a = @path

  def to_h = { @path => @exposed }

  def +(other)
    label = (other.label <=> @label).negative? ? other.label : @label
    Hashira::Coupling::Constant.new(label, @path, @exposed && other.exposed)
  end

  def place = @label.place

  def finding(kind) = @label.finding(kind, :constant)

  def live?(spoken, marks)
    spoken.named?(@path) || LEVELS.include?(@path.last) || marks.reached?(@path) || marks.evaluated?(@label.to_s)
  end

  def held?(anchors, hosting) = @label.rooted?(anchors, @exposed) || hosting.held?(@path, hosts)

  protected

  attr_reader :label, :exposed

  private

  def hosts = @exposed ? [@path[...-1]].reject(&:empty?) : []
end
