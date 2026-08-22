# frozen_string_literal: true

require "prism"

class Hashira::Smells::Gated::Shape
  ANY = Float::INFINITY

  Blank =
    Data.define(:requireds, :optionals, :posts, :keywords, :rest, :keyword_rest) do
      def initialize(requireds: [], optionals: [], posts: [], keywords: [], rest: nil, keyword_rest: nil) = super
    end

  NONE = Blank.new

  def initialize(definition)
    @node = definition
  end

  def opaque? = Hashira::Analysis::NodeWalk.collect(@node).any? { blurred?(it) }

  def narrower?(other) = least > other.least || most < other.most

  def refuses(other) = loose? ? [] : other.keys - keys

  def imposes(other) = demanded - other.demanded

  def least = taken.requireds.size + taken.posts.size

  def most = taken.rest ? ANY : least + taken.optionals.size

  def keys = taken.keywords.filter_map(&:name)

  def demanded = taken.keywords.grep(Prism::RequiredKeywordParameterNode).map(&:name)

  def loose? = !!taken.keyword_rest

  private

  def taken = @_taken ||= @node.parameters || NONE

  def blurred?(node)
    node.is_a?(Prism::ForwardingParameterNode) ||
      (node.is_a?(Prism::ParametersNode) && node.rest.is_a?(Prism::ImplicitRestNode))
  end
end
