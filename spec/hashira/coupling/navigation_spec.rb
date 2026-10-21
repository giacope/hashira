# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Navigation) do
  def models(one, two)
    {
      "config/application.rb" => "module Shop; class Application; end; end\n",
      "app/models/user.rb" => "class User\n  #{one}\nend\n",
      "app/models/post.rb" => "class Post\n  #{two}\nend\n"
    }
  end

  def found(files, *kinds)
    within(files) do
      shown = kinds.empty? ? %w[cycle bidirectional_association] : kinds
      Hashira::Pipeline.new(Hashira::Project.new(["app"])).findings.select { shown.include?(it.kind) }
    end
  end

  it "reports two models that declare associations to each other once, with what the owning side carries" do
    paired = found(models("has_many :posts, dependent: :destroy", "belongs_to :user"))
    pledge = "models/user.rb:2: has_many :posts, dependent: :destroy"
    expect(paired.map { [it.kind, it.package, it.detail] }).to(
      eq(
        [
          [
            "bidirectional_association", "User",
            { parent: "User", children: ["Post"], guarantees: [pledge] }
          ]
        ]
      )
    )
  end

  def owning = "has_many :posts\n  has_many :comments\n  has_one :trn_request, class_name: \"Trs::TrnRequest\""

  def crowd
    models(owning, "belongs_to :user").merge(
      "app/models/comment.rb" => "class Comment\n  belongs_to :user\nend\n",
      "app/models/trs/trn_request.rb" => "module Trs\n  class TrnRequest\n    belongs_to :user\n  end\nend\n"
    )
  end

  it "reports a model once for every model it is navigated both ways with, naming each class, namespaced or not" do
    finding = found(crowd).first
    said = "User is navigated both ways by 3 models, Comment, Post, Trs::TrnRequest: each declares an association " \
      "to the other (user.rb:2), which ties them together. Drop User's side of each and query the model " \
      "where it is needed."
    expect([finding.package, finding.detail[:children], finding.evidence.size, message(finding)])
      .to(eq(["User", %w[Comment Post Trs::TrnRequest], 6, said]))
  end

  it "says which side to drop and what to hand on first" do
    said = "User and Post each declare an association to the other (models/user.rb:2) — navigating both ways ties " \
      "them together. Drop User's side and query Post where it is needed. It carries has_many :posts, dependent: " \
      ":destroy: hand that to an object above both, or to the foreign key, first."
    expect(message(found(models("has_many :posts, dependent: :destroy", "belongs_to :user")).first)).to(eq(said))
  end

  it "takes the first class as the parent when neither or both sides own, and says nothing it does not carry" do
    pairs = [models("belongs_to :post", "belongs_to :user"), models("has_many :posts", "has_many :users")]
    findings = pairs.map { found(it).first }
    said = "Post and User each declare an association to the other (models/post.rb:2) — navigating both ways ties " \
      "them together. Drop Post's side and query User where it is needed."
    expect([findings.map { it.detail[:parent] }, message(findings.first)]).to(eq([%w[Post Post], said]))
  end

  it "leaves a declared pair's edges out of the stability check, since one side is to go" do
    owned = %w[Session Device Token].to_h { ["app/models/#{it.downcase}.rb", "class #{it}\n  belongs_to :user\nend\n"] }
    files = models("has_many :posts", "belongs_to :user\n  has_many :tags").merge(owned)
    tags = { "app/models/tag.rb" => "class Tag\n  def post = Post\nend\n" }
    expect(found(files.merge(tags), "sdp_violation")).to(be_empty)
  end

  it "keeps a declared pair in the cycle search when code reaches both ways besides the declarations" do
    files = models("has_many :posts\n  def latest = Post", "belongs_to :user\n  def owner = User")
    expect(found(files).map(&:kind)).to(eq(%w[cycle bidirectional_association]))
  end
end
