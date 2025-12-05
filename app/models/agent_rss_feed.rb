# frozen_string_literal: true

# Join table between Agent and RssFeed
class AgentRssFeed < ApplicationRecord
  belongs_to :agent
  belongs_to :rss_feed

  validates :agent_id, uniqueness: {scope: :rss_feed_id}
end
