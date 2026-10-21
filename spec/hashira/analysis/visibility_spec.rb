# frozen_string_literal: true

RSpec.describe(Hashira::Analysis::Visibility) do
  def sections(source)
    type = Prism.parse(source).value.statements.body.first
    described_class.new(type).entries.map { |node, section| [node.name, section] }
  end

  it "restores the section a call's block changes, and keeps one a bare marker sets" do
    source = "class C\n  wrap do\n    private\n  end\n  def open = 1\n  private\n  def shut = 1\nend\n"
    expect(sections(source)).to(eq([%i[open public], %i[shut private]]))
  end

  it "reads a module that extends itself as module functions, its private methods aside" do
    source = "module M\n  extend self\n  def shared = 1\n  private\n  def own = 1\nend\n"
    plain = "module N\n  extend Other\n  def shared = 1\nend\n"
    expect([sections(source), sections(plain)])
      .to(eq([[%i[shared module_function], %i[own private]], [%i[shared public]]]))
  end
end
