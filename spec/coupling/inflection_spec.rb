# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Inflection) do
  def inflection(source = nil) = described_class.new(Hashira::Coupling::Inflections.of(source && tree(source)))

  def tree(source) = Prism.parse(source).value

  it "singulars and classifies association names with ActiveSupport's rules" do
    named = %w[
      posts people categories statuses analyses boxes addresses mice line_items news series octopi wives
      databases buses quizzes matrices children moves halves heroes vertices crises axes oxen
    ]
    classes = %w[
      Post Person Category Status Analysis Box Address Mouse LineItem News Series Octopus Wife Database Bus Quiz
      Matrix Child Move Half Hero Vertex Crisis Axis Ox
    ]
    expect(named.map { inflection.classify(it) }).to(eq(classes))
  end

  it "plurals the way Rails names a namespace for a model" do
    words = %w[order person category status analysis box index child quiz sheep salesperson knife]
    plurals = %w[orders people categories statuses analyses boxes indices children quizzes sheep salespeople knives]
    expect(words.map { inflection.plural(it) }).to(eq(plurals))
  end

  it "camelizes paths into constants" do
    expect(inflection.camelize("admin/line_item")).to(eq("Admin::LineItem"))
  end

  it "reads the app's own inflections, which take precedence" do
    source = <<~RUBY
      ActiveSupport::Inflector.inflections(:en) do |inflect|
        inflect.irregular "cactus", "cacti"
        inflect.irregular "solo"
        inflect.plural(/^(ox)$/i, '\\1es')
        inflect.plural "foot", "feet"
        inflect.plural "lone"
        inflect.singular(/^(ox)es$/i, '\\1')
        inflect.singular "feet", "foot"
        inflect.singular "lone"
        inflect.uncountable %w[equipment data]
        inflect.uncountable :moose, name
        inflect.acronym "API"
        inflect.acronym helper
        inflect.acronym
        inflect.singular(/^geese$/, "goose")
      end
      irregular "outside", "ignored"
    RUBY
    found = inflection(source)
    expect(%w[cacti oxes feet data moose api_keys geese Geese].map { found.classify(it) }).to(
      eq(%w[Cactus Ox Foot Data Moose APIKey Goose Geese])
    )
    expect(%w[cactus ox Ox foot football lone outside].map { found.plural(it) }).to(
      eq(%w[cacti oxes Oxes feet footballs lones outsides])
    )
  end
end
