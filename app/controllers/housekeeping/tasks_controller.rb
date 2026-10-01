# frozen_string_literal: true
#
# Kartu tugas housekeeping pada Kanban board:
# - create manual (host/supervisor)
# - move antar kolom (drag & drop) / advance
# - upload image bukti kerja
# - assign housekeeper
module Housekeeping
  class TasksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_task, only: [:show, :move, :advance, :upload, :assign, :cancel]

  # GET /housekeeping/tasks?status=&room_id=&board_id=
  def index
    tasks = HousekeepingTask.includes(:room, :attachments)
    tasks = tasks.where(status: params[:status]) if params[:status].present?
    tasks = tasks.where(housekeeping_board_id: params[:board_id]) if params[:board_id].present?
    tasks = tasks.for_room(params[:room_id]) if params[:room_id].present?
    render json: { tasks: tasks.order(due_at: :asc).map { |t| self.class.serialize_task(t) } }
  end

  # GET /housekeeping/tasks/:id
  def show
    render json: { task: self.class.serialize_task(@task, detailed: true) }
  end

  # POST /housekeeping/tasks (manual, mulai dari kolom draft)
  def create
    room = Room.find(params[:room_id])
    board = params[:board_id].present? ? HousekeepingBoard.find(params[:board_id]) : nil

    board ||= HousekeepingBoard.find_or_create_by!(
      property: room.room_type.hotel&.property || Property.first,
      hotel: room.room_type.hotel
    ) { |b| b.name = "Housekeeping - #{b.property&.name}" }

    task = HousekeepingTask.create!(
      room: room,
      property: board.property,
      hotel: board.hotel,
      board: board,
      title: params[:title] || "Tugas Kamar #{room.room_number}",
      description: params[:description],
      task_type: params[:task_type] || 'cleaning',
      priority: params[:priority] || 'medium',
      status: 'draft',
      due_at: params[:due_at].presence || Time.current.end_of_day,
      triggered_by: 'manual',
      created_by: current_user
    )

    HousekeepingNotifier.notify_task_created(task)
    render json: { task: self.class.serialize_task(task) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  # PATCH /housekeeping/tasks/:id/move   { status: "in_progress" }
  def move
    new_status = params[:status]
    @task.move_to!(new_status, current_user)
    HousekeepingNotifier.notify_status_changed(@task.reload, current_user)
    render json: { task: self.class.serialize_task(@task) }
  rescue ErrorHandling::BookingError, ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /housekeeping/tasks/:id/advance  (pindah ke kolom berikutnya)
  def advance
    @task.advance!(current_user)
    HousekeepingNotifier.notify_status_changed(@task.reload, current_user)
    render json: { task: self.class.serialize_task(@task) }
  rescue ErrorHandling::BookingError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /housekeeping/tasks/:id/upload  (multipart: file=..., caption=...)
  # atau JSON: { file_url:, filename:, content_type:, byte_size: }
  def upload
    result = HousekeepingTaskUploader.new(
      task: @task,
      uploaded_file: params[:file],
      file_url: params[:file_url],
      filename: params[:filename],
      content_type: params[:content_type],
      byte_size: params[:byte_size],
      caption: params[:caption],
      uploader: current_user
    ).call

    if result.success?
      render json: { attachment: result.attachment.as_json(only: %i[id file_url filename kind caption]),
                     photo_count: @task.reload.photo_count }, status: :created
    else
      render json: { errors: result.errors }, status: :unprocessable_entity
    end
  end

  # PATCH /housekeeping/tasks/:id/assign { assigned_to_id: }
  def assign
    @task.update!(assigned_to_id: params[:assigned_to_id])
    @task.log_activity(current_user, "ditugaskan ke user ##{params[:assigned_to_id]}")
    render json: { task: self.class.serialize_task(@task) }
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  # POST /housekeeping/tasks/:id/cancel
  def cancel
    @task.update!(status: 'cancelled')
    @task.log_activity(current_user, "dibatalkan")
    render json: { task: self.class.serialize_task(@task) }
  end

  private

  def set_task
    @task = HousekeepingTask.find(params[:id])
  end

  # Serialisasi kartu Kanban (dipakai juga oleh BoardsController).
  def self.serialize_task(task, detailed: false)
    json = task.as_json(
      only: %i[id title description task_type priority status due_at completed_at
               housekeeping_board_id room_id last_booking_id assigned_to_id created_at],
      methods: %i[photo_count open?]
    )
    json[:room] = task.room.as_json(only: %i[id room_number status])
    json[:attachments] = task.attachments.order(created_at: :desc)
                                .as_json(only: %i[id file_url filename kind caption created_at])
    if detailed
      json[:activities] = HousekeepingActivity.where(housekeeping_task_id: task.id).recent
                                              .as_json(only: %i[action user_id created_at])
    end
    json
  end

  private

  def serialize_task(task, detailed: false)
    self.class.serialize_task(task, detailed: detailed)
  end
end
end
