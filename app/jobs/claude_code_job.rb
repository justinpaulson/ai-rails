class ClaudeCodeJob < ApplicationJob
  queue_as :default

  def perform(conversation_id, prompt)
    conversation = Conversation.find(conversation_id)

    conversation.messages.create!(
      role: :user,
      message_type: :text,
      content: prompt
    )

    service = ClaudeCodeService.new(conversation)
    service.send_message(prompt)
  end
end
