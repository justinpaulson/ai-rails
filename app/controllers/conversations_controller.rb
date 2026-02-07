class ConversationsController < ApplicationController
  before_action :set_conversation, only: [:show, :update, :destroy, :stop, :replay, :status]

  def index
    @conversations = Conversation.order(created_at: :desc).limit(20)
    @conversation = Conversation.new(working_directory: Rails.root.to_s)
  end

  def show
    @messages = @conversation.messages.chronological
  end

  def create
    @conversation = Conversation.new(conversation_params)
    @conversation.working_directory = Rails.root.to_s if @conversation.working_directory.blank?

    if @conversation.save
      if params[:prompt].present?
        ClaudeCodeJob.perform_later(@conversation.id, params[:prompt])
      end
      redirect_to @conversation
    else
      @conversations = Conversation.order(created_at: :desc).limit(20)
      render :index, status: :unprocessable_entity
    end
  end

  def update
    respond_to do |format|
      if @conversation.update(conversation_params)
        format.html { redirect_to @conversation }
        format.json { render json: { success: true, title: @conversation.display_title } }
      else
        format.html { redirect_to @conversation, alert: "Failed to update conversation" }
        format.json { render json: { success: false }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @conversation.destroy
    redirect_to root_path, notice: "Conversation deleted"
  end

  def stop
    if ClaudeCodeService.stop(@conversation)
      @conversation.reload
      respond_to do |format|
        format.html { redirect_to @conversation, notice: "Session stopped" }
        format.json { render json: { success: true } }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to @conversation, alert: "No running session to stop" }
        format.json { render json: { success: false, error: "No running session" }, status: :unprocessable_entity }
        format.turbo_stream
      end
    end
  end

  def replay
    first_user_message = @conversation.messages.where(role: :user, message_type: :text).order(:created_at).first

    if first_user_message.nil?
      redirect_to @conversation, alert: "No user message to replay"
      return
    end

    new_conversation = Conversation.create!(
      working_directory: @conversation.working_directory
    )

    ClaudeCodeJob.perform_later(new_conversation.id, first_user_message.content)
    redirect_to new_conversation
  end

  def status
    render json: { status: @conversation.status }
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:id])
  end

  def conversation_params
    params.require(:conversation).permit(:title, :working_directory)
  end
end
