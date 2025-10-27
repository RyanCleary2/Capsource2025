module FieldPlacementHelper
  # Convert lightweight markdown-like text into safe HTML for display.
  # - converts ## / # headings to h2/h3
  # - converts **bold** to <strong>
  # - preserves line breaks
  # Note: complex list parsing is handled lightly here; the view also contains logic
  # to transform simple <br>-separated list lines into <ul>/<ol> when needed.
  def format_case_text(text)
    return '' if text.blank?
    html = text.to_s.dup

    # Escape HTML first to avoid injection, then do safe replacements
    # We rely on trusted/generated model output, but still minimize risk.
    html = ERB::Util.html_escape(html)

    # Headings: ## -> h2, # -> h3 (allow repeated markers)
    html.gsub!(/^##+\s*(.+)$/) { "<h2>#{Regexp.last_match(1).strip}</h2>" }
    html.gsub!(/^#+\s*(.+)$/)  { "<h3>#{Regexp.last_match(1).strip}</h3>" }

    # Bold markers
    html.gsub!(/\*\*(.+?)\*\*/) { "<strong>#{Regexp.last_match(1)}</strong>" }

    # Convert common numbered/bullet list markers into plain lines (view may convert)
    # Keep them as plain text with line breaks; the frontend transforms lists into <ol>/<ul>.

    # Convert single line breaks to <br> when they are not between tags
    html.gsub!(/([^>])\n([^<])/m, '\1<br>\2')

    html.html_safe
  end

  # Parse generated output into structured sections.
  # Returns a hash: { title:, description:, responsibilities:, outcomes:, other: }
  def parse_field_placement_sections(text)
    t = text.to_s.dup
    t.gsub!("\r\n", "\n")
    sections = { title: nil, description: nil, responsibilities: nil, outcomes: nil, other: nil }

    # Try a tight multi-block capture for the 'ENDS HERE' style output.
    combined_re = /
      Title:\s*(.*?)\s*ENDS HERE\s*\n*\s*
      (?:Field Placement Description|Description)\s*:\s*(.*?)\s*ENDS HERE\s*\n*\s*
      Responsibilities\s*:\s*(.*?)\s*ENDS HERE\s*\n*\s*
      Learning Outcomes\s*:\s*(.*?)\s*ENDS HERE
    /mix

    if (m = t.match(combined_re))
      sections[:title] = m[1].to_s.strip
      sections[:description] = m[2].to_s.strip
      sections[:responsibilities] = m[3].to_s.strip
      sections[:outcomes] = m[4].to_s.strip
      # remove matched blocks from working text
      t.gsub!(combined_re, '')
    else
      # Attempt to capture labeled blocks individually (non-greedy until next label or end)
      label_capture = lambda do |label_variants|
        regex = /(#{label_variants.join('|')})\s*:\s*(.*?)(?=(?:\n[A-Za-z \-]{2,}?:)|\z)/mi
        if mm = t.match(regex)
          val = mm[2].to_s.strip
          # remove the captured block from t for clean fallback parsing
          t.sub!(mm[0], '')
          val
        else
          nil
        end
      end

      sections[:title] = label_capture.call(['Title'])
      sections[:description] = label_capture.call(['Field Placement Description', 'Description'])
      sections[:responsibilities] = label_capture.call(['Field Placement Responsibilities', 'Responsibilities'])
      sections[:outcomes] = label_capture.call(['Learning Outcomes', 'Outcomes'])

      # If title still missing, look for common markdown heading or first short non-empty line
      if sections[:title].blank?
        if (h = text.match(/^#\s*(.+)$/))
          sections[:title] = h[1].strip
        else
          first_line = text.lines.map(&:strip).find { |l| l.present? }
          sections[:title] = first_line if first_line && first_line.length < 140
        end
      end
    end

    # Normalize and clean extracted sections
    sections.each do |k, v|
      next if v.blank?
      s = v.dup
      # Remove bolded label prefixes like '**Description:**' at the start
      s.gsub!(/\A\s*\*{1,2}\s*(?:title|field placement description|description|background|objective|field placement objective statement|field placement responsibilities|responsibilities|learning outcomes|outcomes)\s*\*{1,2}\s*[:\-\—]?\s*/i, '')
      # Remove leading simple 'Title: ' or similar if left
      s.gsub!(/\A\s*Title\s*[:\-\—]\s*/i, '')
      # Strip leading markdown heading markers
      s.gsub!(/\A\s*#+\s*/, '')
      # Remove leftover leading bullets/asterisks on lines
      s.gsub!(/^\s*\*+\s*/m, '')
      # Trim
      sections[k] = sanitize_section(s)
    end

    sections
  end

  private

  # Remove trailing symbol-only lines, trailing sequences of punctuation, normalize bullets,
  # collapse excessive blank lines, and trim.
  def sanitize_section(s)
    return nil if s.blank?
    str = s.to_s.dup
    str.gsub!("\r\n", "\n")

    # Split lines and remove trailing lines that are only punctuation/symbols
    lines = str.lines.map(&:rstrip)
    lines.pop while lines.any? && lines.last.strip.match?(/\A[^\p{Alnum}]+\z/)
    str = lines.join("\n").rstrip

    # Remove trailing punctuation/bullet sequences
    str.gsub!(/[\-\*_•\u2022\—\s]{2,}\z/, '')

    # Normalize bullets at each line start (remove '-', '*', '•') but keep numbering
    str = str.lines.map { |ln| ln.gsub(/^\s*[\-\*\u2022\•]\s?/, '').rstrip }.join("\n")

    # Collapse more than two consecutive blank lines
    str.gsub!(/\n{3,}/, "\n\n")

    str.strip
  end
end
