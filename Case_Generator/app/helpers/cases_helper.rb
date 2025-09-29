module CasesHelper
  # Formats raw case scope/ideas text for HTML rendering
  def format_case_text(text)
    return '' if text.blank?
    html = text.dup
    # Remove leading # from headings and convert to tags
    html.gsub!(/^##\s*#+\s*(.+)$/) { "<h2>#{Regexp.last_match(1).strip}</h2>" }
    html.gsub!(/^##\s*(.+)$/) { "<h2>#{Regexp.last_match(1).strip}</h2>" }
    html.gsub!(/^#\s*#+\s*(.+)$/) { "<h3>#{Regexp.last_match(1).strip}</h3>" }
    html.gsub!(/^#\s*(.+)$/) { "<h3>#{Regexp.last_match(1).strip}</h3>" }
    # Convert **text** to <strong>text</strong>
    html.gsub!(/\*\*(.+?)\*\*/) { "<strong>#{Regexp.last_match(1)}</strong>" }

    # Remove Milestones section entirely
    html.gsub!(/<h2>Milestones<\/h2>.*?(?=<h2>|<h3>|$)/m, '')

    # Convert single line breaks to <br> (but not inside tags)
    html.gsub!(/([^>])\n([^<])/m, '\1<br>\2')
    html.html_safe
  end
end
