class ProfessionalBackground < ApplicationRecord
  belongs_to :profile
  belongs_to :partner, optional: true

  # Helper methods matching CapSource pattern
  def worked_years
    return nil unless start_year.present?

    end_year_value = current_job ? Date.today.year : end_year.to_i
    years = end_year_value - start_year.to_i
    "for #{years} year(s)"
  rescue StandardError
    nil
  end

  def work_range
    return nil unless start_month.present? && start_year.present?

    end_date = current_job ? 'Current' : "#{end_month}/#{end_year}"
    "#{start_month}/#{start_year} - #{end_date}"
  end
end
