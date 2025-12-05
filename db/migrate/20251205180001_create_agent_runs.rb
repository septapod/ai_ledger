# frozen_string_literal: true

class CreateAgentRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_runs, charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci" do |t|
      t.bigint :agent_id, null: false
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.string :status, limit: 20, default: "running", null: false
      t.integer :candidates_found, default: 0, null: false
      t.integer :candidates_vetted, default: 0, null: false
      t.integer :candidates_llm_scored, default: 0, null: false
      t.integer :posts_created, default: 0, null: false
      t.text :error_message
      t.text :metrics, size: :long, default: "{}", collation: "utf8mb4_bin"
      t.string :token, null: false

      t.datetime :created_at, null: false
    end

    add_index :agent_runs, :agent_id
    add_index :agent_runs, :status
    add_index :agent_runs, :token, unique: true
    add_index :agent_runs, [:agent_id, :created_at]
    add_foreign_key :agent_runs, :agents

    reversible do |dir|
      dir.up do
        execute <<-SQL
          ALTER TABLE agent_runs ADD CONSTRAINT agent_run_metrics CHECK (json_valid(metrics));
        SQL
      end
    end
  end
end
