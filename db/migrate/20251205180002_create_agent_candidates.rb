# frozen_string_literal: true

class CreateAgentCandidates < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_candidates, charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci" do |t|
      t.bigint :agent_id, null: false
      t.bigint :agent_run_id, null: false
      t.string :source_type, limit: 20, null: false
      t.bigint :source_id
      t.string :url, limit: 500, null: false
      t.string :title, limit: 500
      t.text :content
      t.float :rule_score
      t.float :llm_score
      t.float :final_score
      t.string :status, limit: 20, default: "pending", null: false
      t.string :rejection_reason, limit: 200
      t.references :story, foreign_key: true, type: :bigint, unsigned: true
      t.string :token, null: false

      t.timestamps
    end

    add_index :agent_candidates, :agent_id
    add_index :agent_candidates, :agent_run_id
    add_index :agent_candidates, :status
    add_index :agent_candidates, :url
    add_index :agent_candidates, :token, unique: true
    add_index :agent_candidates, [:agent_id, :status]
    add_index :agent_candidates, [:agent_id, :url], unique: true
    add_foreign_key :agent_candidates, :agents
    add_foreign_key :agent_candidates, :agent_runs
  end
end
