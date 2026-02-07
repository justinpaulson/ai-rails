class MessagesController < ApplicationController
  before_action :set_conversation

  def create
    prompt = params[:prompt]

    if prompt.present?
      ClaudeCodeService.stop(@conversation) if @conversation.pid.present?
      @conversation.update!(status: :active)
      ClaudeCodeJob.perform_later(@conversation.id, prompt)
    end

    head :ok
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
  end
end
