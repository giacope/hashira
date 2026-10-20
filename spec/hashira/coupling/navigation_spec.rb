# frozen_string_literal: true

RSpec.describe(Hashira::Coupling::Navigation) do
  def models(one, two)
    {
      "config/application.rb" => "module Shop; class Application; end; end\n",
      "app/models/user.rb" => "class User\n  #{one}\nend\n",
      "app/models/post.rb" => "class Post\n  #{two}\nend\n"
    }
  end

  def found(files)
    within(files) do
      Hashira::Pipeline.new(Hashira::Project.new(["app"])).findings.select { %w[cycle bidirectional_association].include?(it.kind) }
    end
  end

  it "reports two models that declare associations to each other once, with what the owning side carries" do
    paired = found(models("has_many :posts, dependent: :destroy", "belongs_to :user"))
    pledge = "models/user.rb:2: has_many :posts, dependent: :destroy"
    expect(paired.map { [it.kind, it.package, it.detail] }).to(
      eq(
        [
          [
            "bidirectional_association", "Post ⇄ User",
            { parent: "User", child: "Post", guarantees: [pledge] }
          ]
        ]
      )
    )
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

  it "keeps a declared pair in the cycle search when code reaches both ways besides the declarations" do
    files = models("has_many :posts\n  def latest = Post", "belongs_to :user\n  def owner = User")
    expect(found(files).map(&:kind)).to(eq(%w[cycle bidirectional_association]))
  end
end
