# frozen_string_literal: true

module Hashira::Report::Phrases
  RETITLE = "keep each name, calling one shared method that takes"

  DUPLICATION_ADVICE = {
    identical: "byte-for-byte identical — extract a shared method and call it from each site.",
    literal: "differs only in literal values — extract a method, pass them as arguments.",
    message: "differs only in the receiver or message — extract a method taking the receiver."
  }.merge(
    constant: "differs only in a constant — extract a method and parameterize it.",
    structure: "the control flow differs — extract the common core, but verify by hand (lower confidence).",
    mixed: "extract the shared shape and pass what differs as parameters."
  ).merge(
    renamed: "the same body under different method names — keep one, and alias it or call it from the others."
  ).merge(
    renamed_literal: "differs in its method names and in literal values — #{RETITLE} the literals as arguments.",
    renamed_message: "differs in its method names and in the receiver or message — #{RETITLE} the receiver."
  ).merge(
    renamed_constant: "differs in its method names and in a constant — #{RETITLE} the constant.",
    renamed_mixed: "differs in its method names and in several other ways — #{RETITLE} what else differs as parameters."
  ).merge(
    nil_guard: "differs only in a `&.` one copy has and the other lacks — extract a method, and decide once " \
      "whether the receiver can be nil.",
    renamed_nil_guard: "differs in its method names and in a `&.` one copy has — keep each name, calling one " \
      "shared method that decides once whether the receiver can be nil."
  ).freeze

  module_function

  def on_duplication(finding)
    detail = finding.detail
    "#{detail.size} similar fragments (mass #{detail.mass}) — " \
      "#{DUPLICATION_ADVICE.fetch(detail.kind)}#{footnote(detail)}"
  end

  def footnote(detail)
    detail.hot ? " Both sites change often — fix one, miss the other." : ""
  end
end
