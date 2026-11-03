# frozen_string_literal: true

require "prism"

RSpec.describe(Hashira::Smells::TypeContext, :aggregate_failures) do
  let(:survey) { Fixtures::LIBRARY }

  let(:type) do
    Prism.parse(<<~RUBY).value.statements.body.first
      class A < B
        def m(a, b = nil, *c, d:, e: 1, &f) = raise(NotImplementedError)
      end
    RUBY
  end

  let(:definition) { type.body.body.first }

  let(:facts) do
    signature = Hashira::Smells::Signature.new(definition)
    heading = Hashira::Smells::Heading.new(type)
    refusal = Hashira::Smells::Refusal.new(definition)
    [
      signature.name, signature.line, signature.arity, heading.parent, heading.written, heading.class?, heading.module?,
      refusal.of, refusal.unimplemented?, Hashira::Smells::Imprint.new(type).to_a
    ]
  end

  it "lets every caller name one of hashira's classes as the reader a context accepts" do
    expect(survey.sites.size).to(be > 50)
    survey.sites.each do |call, scopes|
      expect(call.arguments.arguments.first).to(be_a(Prism::ConstantReadNode).or(be_a(Prism::ConstantPathNode)))
      expect(survey.named(call, scopes)).not_to(be_empty, call.slice)
    end
  end

  it "builds a reader from the context's own node, and does nothing else when it accepts one" do
    expect(survey.accepts.size).to(be >= 4)
    survey.accepts.map { it.body.body }.each do |built|
      expect(built).to(contain_exactly(have_attributes(name: :new, receiver: be_a(Prism::LocalVariableReadNode))))
      expect(built.first.arguments.arguments.first).to(be_a(Prism::InstanceVariableReadNode))
    end
  end

  it "has no reader answer the node it is built from" do
    kept = survey.readers.to_h { [it, survey.kept(it)] }
    expect(kept.count { |_, fields| fields.any? }).to(be > 10)
    kept.each { |name, fields| expect(survey.answered(name) & fields).to(be_empty, name) }
  end

  it "has the readers that tell facts about a node answer names, lines and words, never nodes" do
    parameters = Hashira::Smells::Parameters.new(definition)
    named = [parameters.names, parameters.arguments, parameters.named([Prism::OptionalKeywordParameterNode])]
    expect(named + [parameters.nils]).to(eq([%i[a b d e c f], %i[a b d e c], %i[e], %i[b]]))
    expect(facts.first(9)).to(eq([:m, 2, 1, %w[B], "B", true, false, [:raise], true]))
    expect(facts.flatten.grep(Prism::Node)).to(be_empty)
  end
end
