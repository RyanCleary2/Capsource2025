# frozen_string_literal: true

# Shared parsing helper methods for AI-generated content
# This module provides consistent parsing utilities across all AI service classes
# following the CapSource ProjectScopeGenerator pattern
#
# Usage:
#   class MyAiService
#     include AiParsingHelpers
#
#     def process_content(raw_text)
#       title = extract_field(raw_text, 'TITLE')
#       questions = extract_questions(raw_text)
#       # ... use other helper methods
#     end
#   end
module AiParsingHelpers
  extend ActiveSupport::Concern

  # Extract a specific field from AI-generated content using a flexible regex pattern
  # Matches field names followed by colons and captures content until the next field or end
  #
  # @param content [String] The raw text content to parse
  # @param field_name [String] The field name to extract (case-insensitive)
  # @return [String, nil] The extracted field value, stripped of whitespace, or nil if not found
  #
  # @example
  #   content = "TITLE: Project Manager\nDESCRIPTION: Leading teams"
  #   extract_field(content, 'TITLE')  # => "Project Manager"
  #   extract_field(content, 'DESCRIPTION')  # => "Leading teams"
  def extract_field(content, field_name)
    return nil if content.blank? || field_name.blank?

    # Match field_name: content until next field (uppercase followed by colon) or end of string
    # Updated to handle blank lines correctly - uses \n? to make newline optional
    # and checks that captured content doesn't start with a field marker
    pattern = /#{Regexp.escape(field_name)}:\s*(.+?)(?=\n[A-Z_]+:|$)/mi
    match = content.match(pattern)

    return nil unless match

    extracted = match[1].strip

    # Reject if the extracted value is actually a field marker (e.g., "FACEBOOK:", "TWITTER:")
    # This happens when OpenAI leaves a line blank and the regex captures the next field marker
    return nil if extracted.match?(/^[A-Z_]+:/)

    # Return nil for empty strings
    return nil if extracted.empty?

    extracted
  end

  # Extract questions from various text formats
  # Handles multiple question formats: bullets, numbers, dashes, newlines, question marks
  #
  # @param raw_text [String] The raw text containing questions in various formats
  # @return [Array<String>] Array of cleaned, normalized questions
  #
  # @example
  #   text = "1. What is your goal?\n2. When will you start?"
  #   extract_questions(text)  # => ["What is your goal?", "When will you start?"]
  def extract_questions(raw_text)
    return [] if raw_text.blank?

    questions = extract_individual_questions(raw_text)
    questions.map { |q| clean_question(q) }.reject(&:blank?)
  end

  # Format questions as HTML unordered list for rich text display
  # Converts an array or text block of questions into HTML <ul><li> format
  #
  # @param raw_questions [String, Array] Questions as text or array
  # @return [String] HTML formatted unordered list
  #
  # @example
  #   questions = ["What is your goal?", "When will you start?"]
  #   format_questions_for_rich_text(questions)
  #   # => "<ul>\n<li>What is your goal?</li>\n<li>When will you start?</li>\n</ul>"
  def format_questions_for_rich_text(raw_questions)
    questions_array = raw_questions.is_a?(Array) ? raw_questions : extract_questions(raw_questions)
    return "" if questions_array.empty?

    html_items = questions_array.map { |question| "  <li>#{ERB::Util.html_escape(question)}</li>" }
    "<ul>\n#{html_items.join("\n")}\n</ul>"
  end

  # Format raw text as HTML bullet points
  # Converts any text block into an HTML unordered list by splitting on various separators
  #
  # @param raw_text [String] The raw text to format
  # @param separator [String, Regexp] Optional custom separator (default: newlines, bullets, pipes, commas)
  # @return [String] HTML formatted unordered list
  #
  # @example
  #   text = "Item 1\nItem 2\nItem 3"
  #   format_text_as_bullet_points(text)  # => "<ul>\n<li>Item 1</li>\n<li>Item 2</li>\n<li>Item 3</li>\n</ul>"
  def format_text_as_bullet_points(raw_text, separator: nil)
    return "" if raw_text.blank?

    # Default to splitting on common separators: newlines, bullets, pipes, commas
    separator ||= /[\n|,•·▪▫◦‣⁃]/

    items = raw_text.split(separator)
                    .map(&:strip)
                    .reject(&:blank?)
                    .map { |item| item.gsub(/^\d+[\.\)]\s*/, '').strip } # Remove leading numbers
                    .reject(&:blank?)

    return "" if items.empty?

    html_items = items.map { |item| "  <li>#{ERB::Util.html_escape(item)}</li>" }
    "<ul>\n#{html_items.join("\n")}\n</ul>"
  end

  # Extract individual questions from various formats
  # Handles: bullet points, numbered lists, dash-separated, newline-separated, question mark splitting
  #
  # @param raw_questions [String] The raw text containing questions
  # @return [Array<String>] Array of individual questions (uncleaned)
  #
  # @example
  #   text = "• What is your goal? • When will you start?"
  #   extract_individual_questions(text)  # => ["What is your goal?", "When will you start?"]
  def extract_individual_questions(raw_questions)
    return [] if raw_questions.blank?

    questions = []

    # Strategy 1: Bullet points (•, -, *, etc.)
    bullet_pattern = /[•\-\*·▪▫◦‣⁃]\s*([^•\-\*·▪▫◦‣⁃\n]+)/
    bullet_matches = raw_questions.scan(bullet_pattern).flatten
    questions.concat(bullet_matches) if bullet_matches.any?

    # Strategy 2: Numbered lists (1. 2. 3. or 1) 2) 3))
    numbered_pattern = /\d+[\.\)]\s+([^\d\n]+?)(?=\d+[\.\)]|$)/m
    numbered_matches = raw_questions.scan(numbered_pattern).flatten
    questions.concat(numbered_matches) if numbered_matches.any?

    # Strategy 3: If no bullets or numbers, try splitting by question marks
    if questions.empty?
      question_mark_split = raw_questions.split('?').map { |q| "#{q.strip}?" }
      question_mark_split.pop if question_mark_split.last == '?' # Remove trailing empty question
      questions.concat(question_mark_split) if question_mark_split.any?
    end

    # Strategy 4: If still empty, split by newlines or semicolons
    if questions.empty?
      newline_split = raw_questions.split(/[\n;]/).map(&:strip).reject(&:empty?)
      questions.concat(newline_split)
    end

    # Strategy 5: If we got multiple separators mixed, try to extract by "?"
    if questions.length == 1 && questions.first.count('?') > 1
      questions = questions.first.split(/\?+/).map { |q| "#{q.strip}?" }.reject { |q| q == '?' }
    end

    questions
  end

  # Clean and normalize question text
  # Removes leading numbers, bullets, extra whitespace, and ensures proper punctuation
  #
  # @param question_text [String] The raw question text
  # @return [String] Cleaned question text
  #
  # @example
  #   clean_question("1. What is your goal?  ")  # => "What is your goal?"
  #   clean_question("• When will you start")  # => "When will you start?"
  def clean_question(question_text)
    return "" if question_text.blank?

    cleaned = question_text.strip

    # Remove leading bullets, numbers, and special characters
    cleaned = cleaned.gsub(/^[•\-\*·▪▫◦‣⁃\d\.\)\s]+/, '')

    # Remove trailing punctuation except question marks
    cleaned = cleaned.gsub(/[,;\.\s]+$/, '')

    # Ensure it doesn't end with multiple question marks
    cleaned = cleaned.gsub(/\?+$/, '?')

    # Add question mark if missing and it looks like a question
    if !cleaned.end_with?('?') && cleaned.match?(/^(what|when|where|who|why|how|is|are|can|could|should|would|will|do|does|did)/i)
      cleaned += '?'
    end

    # Capitalize first letter
    cleaned = cleaned[0].upcase + cleaned[1..-1] if cleaned.present? && cleaned[0] =~ /[a-z]/

    cleaned.strip
  end

  # Parse date string in "Month Year" format into separate month and year
  # Handles various date formats and edge cases
  #
  # @param date_str [String] Date string (e.g., "January 2023", "Jan 2023", "2023", "Present")
  # @return [Hash] Hash with :month and :year keys (both can be nil)
  #
  # @example
  #   parse_date_string("January 2023")  # => { month: "January", year: "2023" }
  #   parse_date_string("Present")  # => { month: nil, year: nil }
  #   parse_date_string("2023")  # => { month: nil, year: "2023" }
  def parse_date_string(date_str)
    return { month: nil, year: nil } if date_str.blank?

    date_str = date_str.strip

    # Handle special cases
    return { month: nil, year: nil } if date_str.match?(/present|current|ongoing|now/i)

    # Extract year (4 digits)
    year_match = date_str.match(/\b(19|20)\d{2}\b/)
    year = year_match ? year_match[0] : nil

    # Extract month (full or abbreviated month names)
    month_pattern = /\b(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)\b/i
    month_match = date_str.match(month_pattern)
    month = month_match ? month_match[0].capitalize : nil

    # Normalize abbreviated months to full names if needed
    if month
      month_map = {
        'Jan' => 'January', 'Feb' => 'February', 'Mar' => 'March',
        'Apr' => 'April', 'May' => 'May', 'Jun' => 'June',
        'Jul' => 'July', 'Aug' => 'August', 'Sep' => 'September',
        'Sept' => 'September', 'Oct' => 'October', 'Nov' => 'November',
        'Dec' => 'December'
      }
      month = month_map[month] || month
    end

    { month: month, year: year }
  end

  # Split full name into first name and last name
  # Handles various name formats including middle names, suffixes, and prefixes
  #
  # @param full_name [String] The full name to split
  # @return [Hash] Hash with :first_name and :last_name keys
  #
  # @example
  #   split_full_name("John Doe")  # => { first_name: "John", last_name: "Doe" }
  #   split_full_name("John Michael Doe")  # => { first_name: "John", last_name: "Michael Doe" }
  #   split_full_name("Dr. John Doe Jr.")  # => { first_name: "John", last_name: "Doe" }
  def split_full_name(full_name)
    return { first_name: nil, last_name: nil } if full_name.blank?

    # Clean the name
    name = full_name.strip

    # Remove common prefixes (Dr., Mr., Mrs., Ms., Prof., etc.)
    name = name.gsub(/^(Dr\.|Mr\.|Mrs\.|Ms\.|Miss|Prof\.|Professor)\s+/i, '')

    # Remove common suffixes (Jr., Sr., III, etc.)
    name = name.gsub(/\s+(Jr\.?|Sr\.?|I{1,3}|IV|V|PhD|MD|Esq\.?)$/i, '')

    # Split into parts
    parts = name.split(/\s+/).reject(&:blank?)

    case parts.length
    when 0
      { first_name: nil, last_name: nil }
    when 1
      { first_name: parts[0], last_name: nil }
    when 2
      { first_name: parts[0], last_name: parts[1] }
    else
      # For 3+ parts, first part is first name, rest is last name
      # This handles middle names and compound last names
      { first_name: parts[0], last_name: parts[1..-1].join(' ') }
    end
  end

  # Detect if a job is current based on end date
  # Checks for keywords like "Present", "Current", or nil values
  #
  # @param end_date [String, nil] The end date string to check
  # @return [Boolean] true if the job is current, false otherwise
  #
  # @example
  #   detect_current_job("Present")  # => true
  #   detect_current_job("December 2023")  # => false
  #   detect_current_job(nil)  # => true
  def detect_current_job(end_date)
    return true if end_date.nil? || end_date.blank?

    # Check for "present" or "current" keywords (case-insensitive)
    end_date.to_s.strip.match?(/\b(present|current|ongoing|now)\b/i)
  end

  # Extract numeric value from text (handles thousands separators and decimals)
  # Useful for parsing employee counts, revenue, etc.
  #
  # @param text [String] Text containing a number
  # @return [Float, nil] Extracted numeric value or nil
  #
  # @example
  #   extract_numeric_value("$1,234.56")  # => 1234.56
  #   extract_numeric_value("10,000 employees")  # => 10000.0
  def extract_numeric_value(text)
    return nil if text.blank?

    # Remove currency symbols and commas, then extract number
    number_match = text.gsub(/[$,]/, '').match(/\d+\.?\d*/)
    number_match ? number_match[0].to_f : nil
  end

  # Parse a range string into min and max values
  # Handles formats like "10-20", "10 to 20", "10..20", "10-20K", "$10M-$20M"
  #
  # @param range_str [String] Range string
  # @return [Hash] Hash with :min and :max keys (can be nil)
  #
  # @example
  #   parse_range("10-20")  # => { min: 10.0, max: 20.0 }
  #   parse_range("$100K-$200K")  # => { min: 100.0, max: 200.0 }
  def parse_range(range_str)
    return { min: nil, max: nil } if range_str.blank?

    # Handle various range separators: -, to, .., –, —
    parts = range_str.split(/[-–—]|to|\.\./)
    return { min: nil, max: nil } if parts.length != 2

    min_val = extract_numeric_value(parts[0])
    max_val = extract_numeric_value(parts[1])

    # Handle K (thousands) and M (millions) suffixes
    if range_str.match?(/k/i)
      min_val = min_val * 1000 if min_val
      max_val = max_val * 1000 if max_val
    elsif range_str.match?(/m/i)
      min_val = min_val * 1_000_000 if min_val
      max_val = max_val * 1_000_000 if max_val
    end

    { min: min_val, max: max_val }
  end

  # Extract email addresses from text
  # Returns array of all email addresses found
  #
  # @param text [String] Text to search for emails
  # @return [Array<String>] Array of email addresses
  #
  # @example
  #   extract_emails("Contact us at info@example.com or support@example.com")
  #   # => ["info@example.com", "support@example.com"]
  def extract_emails(text)
    return [] if text.blank?

    email_pattern = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/
    text.scan(email_pattern).uniq
  end

  # Extract phone numbers from text
  # Handles various phone number formats
  #
  # @param text [String] Text to search for phone numbers
  # @return [Array<String>] Array of phone numbers
  #
  # @example
  #   extract_phone_numbers("Call us at (555) 123-4567 or 555-765-4321")
  #   # => ["(555) 123-4567", "555-765-4321"]
  def extract_phone_numbers(text)
    return [] if text.blank?

    phone_patterns = [
      /\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/,  # (555) 123-4567 or 555-123-4567
      /\+\d{1,3}[-.\s]?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/  # +1 (555) 123-4567
    ]

    phones = []
    phone_patterns.each do |pattern|
      matches = text.scan(pattern)
      phones.concat(matches.flatten)
    end

    phones.uniq
  end

  # Extract URLs from text
  # Returns array of all URLs found
  #
  # @param text [String] Text to search for URLs
  # @param exclude_domains [Array<String>] Optional array of domains to exclude
  # @return [Array<String>] Array of URLs
  #
  # @example
  #   extract_urls("Visit https://example.com or www.test.com")
  #   # => ["https://example.com", "www.test.com"]
  def extract_urls(text, exclude_domains: [])
    return [] if text.blank?

    url_pattern = /\b(?:https?:\/\/)?(?:www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:\/[^\s]*)?\b/
    urls = text.scan(url_pattern).uniq

    # Filter out excluded domains
    if exclude_domains.any?
      urls.reject! { |url| exclude_domains.any? { |domain| url.include?(domain) } }
    end

    urls
  end

  # Convert plain text to HTML paragraphs
  # Splits text by double newlines and wraps each paragraph in <p> tags
  #
  # @param text [String] Plain text
  # @return [String] HTML with paragraph tags
  #
  # @example
  #   text_to_html_paragraphs("First paragraph.\n\nSecond paragraph.")
  #   # => "<p>First paragraph.</p>\n<p>Second paragraph.</p>"
  def text_to_html_paragraphs(text)
    return "" if text.blank?

    paragraphs = text.split(/\n\s*\n/).map(&:strip).reject(&:blank?)
    paragraphs.map { |p| "<p>#{ERB::Util.html_escape(p)}</p>" }.join("\n")
  end

  # Truncate text to a specified length with ellipsis
  # Word-aware truncation that doesn't cut words in the middle
  #
  # @param text [String] Text to truncate
  # @param length [Integer] Maximum length (default: 100)
  # @param omission [String] String to append when truncated (default: "...")
  # @return [String] Truncated text
  #
  # @example
  #   truncate_text("This is a long sentence that needs truncating", length: 20)
  #   # => "This is a long..."
  def truncate_text(text, length: 100, omission: '...')
    return "" if text.blank?
    return text if text.length <= length

    # Find the last space before the length limit
    truncated = text[0...length]
    last_space = truncated.rindex(' ')

    if last_space
      "#{text[0...last_space]}#{omission}"
    else
      "#{truncated}#{omission}"
    end
  end

  # Sanitize text for safe HTML display
  # Removes potentially dangerous HTML tags while preserving line breaks
  #
  # @param text [String] Text to sanitize
  # @return [String] Sanitized text
  def sanitize_text(text)
    return "" if text.blank?

    # Remove HTML tags except basic formatting
    sanitized = ActionController::Base.helpers.sanitize(
      text,
      tags: %w[p br strong em u b i],
      attributes: []
    )

    sanitized.strip
  end
end
