class MemberPoint < ApplicationRecord
  belongs_to :user
  belongs_to :facility_booking
  
  validates :points, numericality: { greater_than: 0 }
  
  scope :active, -> { where(expired: false).where('expires_at > ?', Date.today) }
  scope :expired, -> { where(expired: true).or(where('expires_at <= ?', Date.today)) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  
  # Calculate total active points for a user
  def self.total_active_points(user_id)
    active.for_user(user_id).sum(:points)
  end
  
  # Expire old points
  def self.expire_old_points!
    active.where('expires_at <= ?', Date.today).update_all(expired: true)
  end
  
  # Redeem points
  def self.redeem_points(user_id, points_to_redeem)
    ActiveRecord::Base.transaction do
      active_points = active.for_user(user_id).order(expires_at: :asc)
      remaining = points_to_redeem
      
      active_points.each do |point_record|
        break if remaining <= 0
        
        if point_record.points <= remaining
          point_record.update!(expired: true)
          remaining -= point_record.points
        else
          new_balance = point_record.points - remaining
          point_record.update!(points: new_balance)
          remaining = 0
        end
      end
      
      if remaining > 0
        throw(:abort, "Insufficient points")
      end
      
      true
    end
  end
end
