module App
  class Organization
    def members = []

    def push_notifiable_members = members.select(&:notify?)
  end

  class Linkset
    def update!(home:) = home
  end

  class Rubygem
    attr_reader :organization, :name
    attr_accessor :linkset
  end

  class Version
    attr_reader :rubygem, :number
  end

  class Yank
    def initialize(version)
      @version = version
    end

    def notify(rubygem)
      rubygem.organization.push_notifiable_members.each { |member| member.mail(@version) }
    end

    def gem_name = @version.rubygem
  end

  class LinksetJob
    def perform(version, homepage)
      version.rubygem.linkset ||= Linkset.new
      version.rubygem.linkset.update!(home: homepage)
    end
  end
end
