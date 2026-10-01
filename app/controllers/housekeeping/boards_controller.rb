# frozen_string_literal: true
#
# Kanban board housekeeping: draft -> todo -> in_progress -> review -> done.
module Housekeeping
  class BoardsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_board, only: [:show]

  # GET /housekeeping/boards
  def index
    boards = HousekeepingBoard.where(property_id: current_user.properties.select(:id))
    boards = HousekeepingBoard.all if boards.empty? && current_user.admin?
    render json: {
      boards: boards.map { |b|
        b.as_json(only: %i[id name property_id hotel_id]).merge(task_counts: b.task_counts)
      }
    }
  end

  # GET /housekeeping/boards/:id
  # Response siap-render UI Kanban (kolom per status, kartu terurut prioritas).
  def show
    columns = @board.columns(with_open_tasks_only: params[:open_only].present?)
    render json: {
      board: @board.as_json(only: %i[id name property_id hotel_id]),
      columns: HousekeepingBoard::DEFAULT_COLUMNS.map { |col|
        {
          key: col,
          tasks: columns[col].map { |t| Housekeeping::TasksController.serialize_task(t) }
        }
      },
      counts: @board.task_counts
    }
  end

  private

  def set_board
    @board = HousekeepingBoard.find(params[:id])
  end

end
end
