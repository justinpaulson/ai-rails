class Message < ApplicationRecord
  belongs_to :conversation

  after_create_commit :broadcast_message
  after_create_commit :check_for_todo_update
  after_create_commit :maybe_generate_title

  enum :role, { user: "user", assistant: "assistant", system: "system" }
  enum :message_type, {
    text: "text",
    tool_use: "tool_use",
    tool_result: "tool_result",
    system_init: "system_init",
    result: "result"
  }, default: :text

  validates :role, presence: true
  validates :content, presence: true, if: -> { text? }

  scope :chronological, -> { order(created_at: :asc) }

  def tool_input_parsed
    return {} unless tool_input.present?
    tool_input.is_a?(String) ? JSON.parse(tool_input) : tool_input
  rescue JSON::ParserError
    {}
  end

  def matching_tool_use
    return nil unless tool_result? && tool_use_id.present?
    conversation.messages.find_by(message_type: :tool_use, tool_use_id: tool_use_id)
  end

  def todo_write_call?
    tool_use? && tool_name == "TodoWrite"
  end

  private

  def check_for_todo_update
    return unless todo_write_call?

    todos = tool_input_parsed["todos"]
    return unless todos.is_a?(Array)

    conversation.update_todos!(todos)
  end

  def broadcast_message
    case message_type
    when "tool_use"
      broadcast_tool_call(self, nil)
    when "tool_result"
      tool_use_msg = matching_tool_use
      if tool_use_msg
        broadcast_tool_call(tool_use_msg, self)
      end
    else
      Turbo::StreamsChannel.broadcast_append_to(
        conversation,
        target: "messages",
        partial: "messages/message",
        locals: { message: self }
      )
    end
  end

  def maybe_generate_title
    return unless assistant? && text?
    return unless conversation.title.blank? || conversation.title == "New Conversation"

    assistant_text_count = conversation.messages.where(role: :assistant, message_type: :text).count
    return unless assistant_text_count == 1

    GenerateTitleJob.perform_later(conversation.id)
  end

  def broadcast_tool_call(tool_use_msg, tool_result_msg)
    target_id = "tool-call-#{tool_use_msg.tool_use_id}"

    if tool_result_msg.nil?
      Turbo::StreamsChannel.broadcast_append_to(
        conversation,
        target: "messages",
        partial: "messages/tool_call",
        locals: { tool_use: tool_use_msg, tool_result: nil }
      )
    else
      Turbo::StreamsChannel.broadcast_replace_to(
        conversation,
        target: target_id,
        partial: "messages/tool_call",
        locals: { tool_use: tool_use_msg, tool_result: tool_result_msg }
      )
    end
  end
end
