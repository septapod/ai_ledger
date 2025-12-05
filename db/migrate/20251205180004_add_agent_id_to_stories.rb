# frozen_string_literal: true

class AddAgentIdToStories < ActiveRecord::Migration[8.0]
  def change
    add_column :stories, :agent_id, :bigint, null: true
    add_index :stories, :agent_id
    add_foreign_key :stories, :agents
  end
end
