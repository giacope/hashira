module App
  class Roster
    def active(members, banned)
      kept = members.select { |member| member.enabled }
      kept = kept.reject { |member| banned.include?(member.id) } unless banned.empty?
      logger.info("kept #{kept.size} of #{members.size}")
      kept
    end
  end
end
