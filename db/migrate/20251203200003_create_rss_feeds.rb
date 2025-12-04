# frozen_string_literal: true

class CreateRssFeeds < ActiveRecord::Migration[8.0]
  def change
    create_table :rss_feeds do |t|
      t.string :name, null: false
      t.string :url, null: false
      t.string :category, limit: 50
      t.boolean :active, default: true, null: false
      t.datetime :last_fetched_at
      t.string :last_error
      t.integer :fetch_count, default: 0, null: false
      t.integer :story_count, default: 0, null: false
      t.json :settings, default: {}

      t.timestamps
    end

    add_index :rss_feeds, :url, unique: true
    add_index :rss_feeds, :active
    add_index :rss_feeds, :category

    create_table :rss_feed_items do |t|
      t.references :rss_feed, null: false, foreign_key: true
      t.references :story, foreign_key: true
      t.string :guid, null: false
      t.string :url, null: false, limit: 500
      t.string :title, limit: 500
      t.text :content
      t.datetime :published_at
      t.float :relevance_score
      t.string :processing_status, limit: 20, default: "pending", null: false
      t.text :processing_notes

      t.timestamps
    end

    add_index :rss_feed_items, :guid
    add_index :rss_feed_items, :processing_status
    add_index :rss_feed_items, [:rss_feed_id, :guid], unique: true
  end
end
