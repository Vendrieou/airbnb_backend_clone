class InvoicePolicy < ApplicationPolicy
  def index?
    user&.has_role?(:billing_admin) || user&.has_role?(:accountant) || user&.admin?
  end

  def show?
    return false unless user.present?
    record.hotel_id == user&.hotel_id || user&.admin? || user&.has_role?(:billing_admin)
  end

  def create?
    user&.has_role?(:billing_admin) || user&.has_role?(:accountant) || user&.admin?
  end

  def update?
    return false if record.posted? || record.paid?
    user&.has_role?(:billing_admin) || user&.admin?
  end

  def destroy?
    return false unless record.draft?
    user&.admin?
  end

  def post?
    return false unless record.draft?
    user&.has_role?(:billing_admin) || user&.admin?
  end

  def pay?
    return false unless record.posted?
    user&.has_role?(:billing_admin) || user&.has_role?(:accountant) || user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user.present?
      return scope if user.admin? || user.has_role?(:billing_admin)
      
      # Accountants can only see invoices from their hotel
      if user.has_role?(:accountant) && user.hotel_id.present?
        scope.where(hotel_id: user.hotel_id)
      else
        scope.none
      end
    end
  end
end
