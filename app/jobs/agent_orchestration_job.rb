# frozen_string_literal: true

# Orchestrates agent execution - runs every 5 minutes
# Checks which agents are due for their scheduled run and enqueues execution jobs
class AgentOrchestrationJob < ApplicationJob
  queue_as :default

  def perform
    return unless agents_enabled?

    Rails.logger.info "[AgentOrchestrationJob] Starting agent orchestration..."

    agents_due = Agent.due_for_run
    Rails.logger.info "[AgentOrchestrationJob] Found #{agents_due.count} agents due for execution"

    agents_due.find_each do |agent|
      # Schedule next run immediately to prevent duplicate runs
      agent.schedule_next_run!

      Rails.logger.info "[AgentOrchestrationJob] Queuing execution for agent: #{agent.name}"
      AgentExecutionJob.perform_later(agent.id)
    end

    Rails.logger.info "[AgentOrchestrationJob] Queued #{agents_due.count} agent execution jobs"
  end

  private

  def agents_enabled?
    # Can be disabled via config if needed
    Rails.application.config.ai_ledger.agents_enabled != false
  end
end
