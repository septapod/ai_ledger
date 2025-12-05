# frozen_string_literal: true

class CreateAgentRssFeeds < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_rss_feeds, charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci" do |t|
      t.bigint :agent_id, null: false
      t.bigint :rss_feed_id, null: false
    end

    add_index :agent_rss_feeds, :agent_id
    add_index :agent_rss_feeds, :rss_feed_id
    add_index :agent_rss_feeds, [:agent_id, :rss_feed_id], unique: true
    add_foreign_key :agent_rss_feeds, :agents
    add_foreign_key :agent_rss_feeds, :rss_feeds
  end
end
