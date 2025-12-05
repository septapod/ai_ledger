# frozen_string_literal: true

class CreateAgents < ActiveRecord::Migration[8.0]
  def change
    create_table :agents, charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci" do |t|
      t.bigint :user_id, null: false, unsigned: true
      t.string :name, limit: 100, null: false
      t.text :description
      t.boolean :enabled, default: false, null: false
      t.string :schedule_interval, limit: 50, default: "daily", null: false
      t.integer :posts_per_run, default: 10, null: false
      t.integer :max_daily_posts, default: 50, null: false
      t.string :trust_level, limit: 20, default: "review", null: false
      t.text :search_config, size: :long, default: "{}", collation: "utf8mb4_bin"
      t.text :quality_config, size: :long, default: "{}", collation: "utf8mb4_bin"
      t.text :settings, size: :long, default: "{}", collation: "utf8mb4_bin"
      t.datetime :last_run_at
      t.datetime :next_run_at
      t.integer :run_count, default: 0, null: false
      t.integer :post_count, default: 0, null: false
      t.string :token, null: false

      t.timestamps
    end

    add_index :agents, :user_id
    add_index :agents, :enabled
    add_index :agents, :next_run_at
    add_index :agents, :trust_level
    add_index :agents, :token, unique: true
    add_foreign_key :agents, :users

    # JSON validation for MariaDB
    reversible do |dir|
      dir.up do
        execute <<-SQL
          ALTER TABLE agents ADD CONSTRAINT search_config CHECK (json_valid(search_config));
        SQL
        execute <<-SQL
          ALTER TABLE agents ADD CONSTRAINT quality_config CHECK (json_valid(quality_config));
        SQL
        execute <<-SQL
          ALTER TABLE agents ADD CONSTRAINT agent_settings CHECK (json_valid(settings));
        SQL
      end
    end
  end
end
