# frozen_string_literal: true

class Hashira::Smells::Probing
  BUILDERS = {
    "control_parameter" => :control_parameter, "feature_envy" => :feature_envy, "manual_dispatch" => :manual_dispatch,
    "message_chain" => :message_chain, "nil_check" => :nil_check, "repeated_call" => :repeated_call,
    "utility_function" => :utility_function
  }.freeze

  private_constant :BUILDERS

  def self.build(trees, walk, ownership, names)
    new(
      names, Hashira::Smells::Words.new(trees), Hashira::Smells::Ties.build(trees, walk, ownership),
      Hashira::Smells::Callers.new(trees, ownership)
    )
  end

  def initialize(names, words, ties, callers)
    @names = names
    @words = words
    @ties = ties
    @callers = callers
  end

  def checks(subject, kinds, rules) = kinds.map { __send__(builder(it), subject, rules) }

  private

  def builder(kind) = BUILDERS.fetch(Hashira::Smells::Kind.new(kind).to_s)

  def control_parameter(subject, rules) = Hashira::Smells::ControlParameter.new(subject, rules, @callers)

  def feature_envy(subject, rules, refs = refs(subject))
    Hashira::Smells::FeatureEnvy.new(subject, rules, refs, Hashira::Smells::Patrons.new(foreign(subject), refs, @words))
  end

  def manual_dispatch(subject, rules, switches = subject.accept(Hashira::Smells::Switches, @names, subject.home.to_s))
    probes = Hashira::Smells::Probes.new(subject, foreign(subject), @words)
    Hashira::Smells::ManualDispatch.new(subject, rules, probes, switches)
  end

  def message_chain(subject, rules) = Hashira::Smells::MessageChain.new(subject, rules, @words, @names)

  def nil_check(subject, rules, writes = writes(subject), foreign = foreign(subject, writes))
    holders = Hashira::Smells::Holders.new(subject, foreign, @names, @ties)
    inputs = Hashira::Smells::Inputs.new(subject, rules)
    locals = Hashira::Smells::Locals.new(subject, writes, foreign, @words)
    speech = Hashira::Smells::Speech.new(subject, @words)
    answers = Hashira::Smells::Answers.new(speech, locals, holders, inputs)
    provenance = Hashira::Smells::Provenance.new(inputs, writes, answers, holders)
    Hashira::Smells::NilCheck.new(subject, rules, foreign, provenance)
  end

  def repeated_call(subject, rules) = Hashira::Smells::RepeatedCall.build(subject, rules, @ties)

  def utility_function(subject, rules) = Hashira::Smells::UtilityFunction.new(subject, rules, refs(subject))

  def refs(subject) = subject.accept(Hashira::Smells::Refs, @words)

  def writes(subject) = subject.accept(Hashira::Smells::Writes)

  def foreign(subject, writes = writes(subject)) = Hashira::Smells::Foreign.new(subject, @names, writes)
end
