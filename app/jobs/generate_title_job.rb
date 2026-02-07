class GenerateTitleJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation
    return if conversation.title.present? && conversation.title != "New Conversation"

    first_user_msg = conversation.messages.where(role: :user, message_type: :text).first
    return unless first_user_msg

    first_assistant_msg = conversation.messages.where(role: :assistant, message_type: :text).first

    context = first_user_msg.content.to_s.truncate(300)
    if first_assistant_msg
      context += "\n\nAssistant: #{first_assistant_msg.content.to_s.truncate(200)}"
    end

    title = generate_title_with_haiku(context)

    if title.present?
      conversation.update!(title: title)
      broadcast_title_update(conversation)
    end
  rescue => e
    Rails.logger.error "[GenerateTitleJob] Error: #{e.message}"
  end

  private

  def generate_title_with_haiku(context)
    require "open3"

    prompt = "Generate a short, descriptive title (3-6 words) for this conversation. Return ONLY the title, no quotes or explanation:\n\n#{context}"

    stdout, stderr, status = Open3.capture3(
      "claude", "--model", "haiku", "--print", "--no-session-persistence", "-p", prompt,
      chdir: Dir.home
    )

    if status.success?
      title = stdout.strip.gsub(/^["']|["']$/, "").truncate(60)
      title.present? ? title : nil
    else
      Rails.logger.error "[GenerateTitleJob] Claude error: #{stderr}"
      nil
    end
  end

  def broadcast_title_update(conversation)
    # Update sidebar title
    Turbo::StreamsChannel.broadcast_replace_to(
      :conversations,
      target: "conversation-#{conversation.id}-title",
      html: conversation.display_title
    )

    # Update header title if viewing this conversation
    Turbo::StreamsChannel.broadcast_replace_to(
      conversation,
      target: "conversation-title",
      html: "<h1 class=\"text-lg font-semibold text-white cursor-pointer hover:bg-gray-700 rounded px-1 -mx-1 outline-none focus:ring-2 focus:ring-blue-500\" id=\"conversation-title\" data-inline-edit-target=\"display\" data-action=\"click->inline-edit#startEdit keydown->inline-edit#handleKeydown blur->inline-edit#handleBlur\" title=\"Click to rename\">#{ERB::Util.html_escape(conversation.display_title)}</h1>"
    )
  end
end
