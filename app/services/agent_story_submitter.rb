# frozen_string_literal: true

# Submits a candidate as a Story on behalf of an Agent
class AgentStorySubmitter
  def initialize(agent, candidate)
    @agent = agent
    @candidate = candidate
    @user = agent.user
  end

  def submit!
    Rails.logger.info "[AgentStorySubmitter] Submitting: #{@candidate.truncated_title}"

    # Validate user exists
    unless @user
      return {success: false, error: "Agent has no associated user"}
    end

    # Create the story
    story = build_story
    unless story.valid?
      return {success: false, error: story.errors.full_messages.join(", ")}
    end

    # Save with proper approval status
    Story.transaction do
      story.save!
      set_approval_status!(story)

      # Update agent's relationship
      @agent.increment_post_count!(1)
    end

    Rails.logger.info "[AgentStorySubmitter] Created story: #{story.short_id}"
    {success: true, story: story}

  rescue ActiveRecord::RecordInvalid => e
    {success: false, error: e.message}
  rescue => e
    Rails.logger.error "[AgentStorySubmitter] Error: #{e.message}"
    {success: false, error: e.message}
  end

  private

  def build_story
    story = Story.new(
      user: @user,
      agent: @agent,
      title: clean_title,
      url: @candidate.url,
      description: build_description
    )

    # Assign default tags based on agent settings or use AI tag
    story.tags = default_tags

    story
  end

  def clean_title
    title = @candidate.title.to_s.strip

    # Remove leading site names (common pattern: "Site Name | Actual Title")
    title = title.sub(/^[^|:]+[|:]\s*/, "") if title.match?(/^[^|:]{1,30}[|:]/)

    # Truncate to fit validation (max 150 chars)
    title.truncate(150)
  end

  def build_description
    content = @candidate.content.to_s.strip
    return nil if content.blank?

    # Use first paragraph as description
    first_para = content.split(/\n\n/).first.to_s.strip
    first_para.truncate(500) if first_para.present?
  end

  def default_tags
    # Get tags from agent settings or use a default "ai" tag
    tag_names = @agent.setting("default_tags") || ["ai"]

    Tag.where(tag: tag_names, active: true)
  end

  def set_approval_status!(story)
    if @agent.auto_approve?
      # Trusted agents get auto-approved
      story.update!(
        approval_status: "approved",
        approved_at: Time.current,
        approved_by_user_id: @user.id
      )
    else
      # Review-level agents need approval
      story.update!(approval_status: "pending")
    end
  end
end
