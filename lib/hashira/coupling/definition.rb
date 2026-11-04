# frozen_string_literal: true

class Hashira::Coupling::Definition
  def initialize(node, path, scope, file)
    @node = node
    @path = path
    @scope = scope
    @file = file
  end

  def to_a = @path

  def form = Hashira::Coupling::Form.new(@node)

  def site = Hashira::Coupling::Site.new(@path, @scope, @file)

  def kin = Hashira::Coupling::Kin.new(@node, @scope)
end
