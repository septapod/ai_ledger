# frozen_string_literal: true

# Submits stories from RSS feed items on behalf of the bot user
class BotStorySubmitter
  def initialize(feed_item)
    @feed_item = feed_item
  end

  # Submit the feed item as a story
  def submit!
    return {success: false, error: "Cannot submit"} unless can_submit?

    ActiveRecord::Base.transaction do
      story = create_story
      @feed_item.mark_submitted!(story)
      {success: true, story: story}
    end
  rescue ActiveRecord::RecordInvalid => e
    @feed_item.mark_error!(e.message)
    {success: false, error: e.message}
  end

  private

  def can_submit?
    return false unless bot_user&.can_auto_submit?
    return false unless bot_user.can_submit_more_today?
    return false unless @feed_item.relevant?
    true
  end

  def create_story
    story = Story.new(
      user: bot_user,
      url: @feed_item.url,
      title: clean_title(@feed_item.title),
      description: generate_description
    )

    # Apply tags
    tag_names = determine_tags
    story.tags = Tag.where(tag: tag_names)

    # Set as pending (bot submissions always need approval)
    story.approval_status = "pending"

    story.save!
    story
  end

  def clean_title(title)
    return "" if title.blank?

    # Remove common suffixes like " | Site Name" or " - Site Name"
    cleaned = title
      .gsub(/\s*[\|\-\u2013\u2014]\s*[^|\-\u2013\u2014]+$/, "")
      .strip

    # Truncate to fit Story title limit
    cleaned.truncate(150)
  end

  def generate_description
    return nil if @feed_item.content.blank?

    # Extract first paragraph as description
    paragraphs = @feed_item.content.split(/\n\n|\r\n\r\n/)
    first_para = paragraphs.first&.strip

    return nil if first_para.blank?

    # Truncate and add source attribution
    truncated = first_para.truncate(400)
    "#{truncated}\n\n*Via #{@feed_item.rss_feed.name}*"
  end

  def determine_tags
    feed_tags = @feed_item.rss_feed.default_tags || []

    # Auto-detect additional tags based on content
    detected_tags = []
    text = "#{@feed_item.title} #{@feed_item.content}".downcase

    # AI-related tags
    detected_tags << "machine-learning" if text.match?(/machine learning|ml model|neural/)
    detected_tags << "generative-ai" if text.match?(/llm|chatgpt|gpt|generative|claude/)
    detected_tags << "automation" if text.match?(/automat|rpa|workflow/)

    # Credit union/fintech tags
    detected_tags << "fraud-detection" if text.match?(/fraud|security|breach/)
    detected_tags << "lending" if text.match?(/loan|lending|mortgage|underwriting/)
    detected_tags << "compliance" if text.match?(/compliance|regulat|ncua|audit/)
    detected_tags << "member-services" if text.match?(/member service|member experience|cx/)

    # Combine and dedupe
    all_tags = (feed_tags + detected_tags).uniq

    # Limit to valid, active tags
    Tag.active.where(tag: all_tags).pluck(:tag).take(5)
  end

  def bot_user
    @bot_user ||= User.ai_agent
  end
end
