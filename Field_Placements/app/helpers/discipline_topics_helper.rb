require 'csv'

module DisciplineTopicsHelper
  # Reads the config CSV and returns a hash mapping discipline => [topics]
  # CSV format expected: first row = discipline headers, subsequent rows = topic values in each column
  def discipline_topics_mapping
    # Try several likely locations for the CSV. Depending on how the Rails app is started,
    # Rails.root may already be the `Field_Placements` folder or the repository root.
    candidates = [
      Rails.root.join('Field_Placements', 'config', 'discipline_topics.csv'),
      Rails.root.join('config', 'discipline_topics.csv'),
      Rails.root.join('Field_Placements', 'Field_Placements', 'config', 'discipline_topics.csv')
    ].map(&:to_s).uniq

    csv_path_str = candidates.find { |p| File.exist?(p) }
    unless csv_path_str
      Rails.logger.error "discipline_topics.csv not found. Checked: #{candidates.join(', ')}"
      return {}
    end

    csv_path = Pathname.new(csv_path_str)

    # Read CSV with safe UTF-8 handling (BOM tolerant)
    rows = CSV.read(csv_path, headers: false, encoding: 'bom|utf-8')
    return {} if rows.empty?

    headers = rows.shift.map { |h| h.to_s.strip }
    mapping = {}
    headers.each_with_index do |header, col_idx|
      next if header.blank?
      mapping[header] = []
      rows.each do |r|
        cell = r[col_idx]
        next if cell.nil?
        val = cell.to_s.strip
        next if val.empty?
        mapping[header] << val
      end
      # uniq and compact
      mapping[header] = mapping[header].map(&:strip).reject(&:empty?).uniq
    end

    mapping
  rescue => e
    Rails.logger.error "Error reading discipline_topics.csv: #{e.message}"
    {}
  end

  # Returns the mapping as a JSON string safe to embed into JS
  def discipline_topics_json
    discipline_topics_mapping.to_json.html_safe
  end

  # Convert a topic label into a slug suitable for form values (mirrors the client-side slugify)
  def slugify_topic(label)
    label.to_s.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')
  end

  # Given an array of topic slugs, map them back to their original labels.
  # If a slug can't be found in the CSV mapping, fall back to a humanized form of the slug.
  def map_topic_slugs_to_labels(slugs)
    return [] if slugs.blank?
    mapping = discipline_topics_mapping
    slugs.map do |s|
      found = nil
      mapping.each do |_disc, topics|
        found = topics.find { |t| slugify_topic(t) == s }
        break if found
      end
      found || s.to_s.gsub('-', ' ').titleize
    end
  end
end
