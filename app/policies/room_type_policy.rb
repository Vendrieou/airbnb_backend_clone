class RoomTypePolicy < ApplicationPolicy
  def index?
    user&.has_role?(:maintenance) || user&.has_role?(:billing_admin) || user&.admin?
  end

  def show?
    index?
  end

  def create?
    user&.has_role?(:billing_admin) || user&.admin?
  end

  def update?
    user&.has_role?(:maintenance) || user&.has_role?(:billing_admin) || user&.admin?
  end

  def destroy?
    user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user.present?
      return scope if user.admin?
      
      if user.has_role?(:billing_admin) || user.has_role?(:maintenance)
        scope.all
      else
        scope.where(active: true)
      end
    end
  end
end
