require 'httparty'
require 'nokogiri'

class OrganizationScraper
  def initialize(url)
    @url = normalize_url(url)
  end

  def scrape
    Rails.logger.info "Scraping URL: #{@url}"

    begin
      # Try with full browser headers first
      response = fetch_with_retry(@url, retries: 2)

      if response.success?
        parse_content(response.body, response.headers['content-type'])
      else
        Rails.logger.warn "HTTP #{response.code} received, attempting to use limited data"
        # For 403/blocked sites, return minimal scraped data
        if response.code == 403
          return generate_fallback_data
        else
          raise "Failed to fetch website: HTTP #{response.code}"
        end
      end
    rescue => e
      Rails.logger.error "Scraping error: #{e.message}"
      # Try fallback with just the URL
      return generate_fallback_data
    end
  end

  def fetch_with_retry(url, retries: 2)
    attempt = 0
    last_error = nil

    while attempt <= retries
      begin
        return HTTParty.get(url,
          timeout: 30,
          follow_redirects: true,
          headers: {
            'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language' => 'en-US,en;q=0.9',
            'Accept-Encoding' => 'gzip, deflate, br',
            'Connection' => 'keep-alive',
            'Upgrade-Insecure-Requests' => '1',
            'Sec-Fetch-Dest' => 'document',
            'Sec-Fetch-Mode' => 'navigate',
            'Sec-Fetch-Site' => 'none',
            'Cache-Control' => 'max-age=0'
          }
        )
      rescue => e
        last_error = e
        attempt += 1
        sleep(1) if attempt <= retries
      end
    end

    raise last_error if last_error
  end

  def generate_fallback_data
    # When scraping fails, return minimal data that AI can work with
    Rails.logger.info "Using fallback data for #{@url}"
    domain = extract_domain(@url)

    {
      title: domain,
      meta_description: "Organization website",
      headings: [domain],
      paragraphs: ["This organization's website could not be fully scraped. Profile will be generated based on available information."],
      links: [],
      contact_info: {
        emails: [],
        phones: [],
        addresses: []
      },
      raw_text: "Website: #{@url}. Domain: #{domain}. Additional information may need to be manually entered."
    }
  end

  def extract_domain(url)
    uri = URI.parse(url)
    domain = uri.host || url
    # Remove www. if present
    domain.sub(/^www\./, '').split('.').first.capitalize
  rescue
    url.split('/')[2]&.sub(/^www\./, '')&.split('.')&.first&.capitalize || "Organization"
  end

  private

  def normalize_url(url)
    # Ensure URL has a protocol
    url = url.strip
    unless url.start_with?('http://', 'https://')
      url = 'https://' + url
    end
    url
  end

  def parse_content(html, content_type)
    doc = Nokogiri::HTML(html)

    # Extract social media links BEFORE removing footer
    social_media_links = extract_social_media_links(doc)

    # Remove script and style elements (but keep footer for now)
    doc.css('script, style, iframe').remove

    # Extract text content
    {
      title: extract_title(doc),
      meta_description: extract_meta_description(doc),
      headings: extract_headings(doc),
      paragraphs: extract_paragraphs(doc),
      links: extract_links(doc),
      social_media: social_media_links,
      contact_info: extract_contact_info(doc),
      raw_text: doc.css('body').text.gsub(/\s+/, ' ').strip[0..10000] # Limit to 10k chars
    }
  end

  def extract_title(doc)
    doc.css('title').first&.text&.strip ||
    doc.css('h1').first&.text&.strip ||
    ''
  end

  def extract_meta_description(doc)
    doc.css('meta[name="description"]').first&.[]('content')&.strip ||
    doc.css('meta[property="og:description"]').first&.[]('content')&.strip ||
    ''
  end

  def extract_headings(doc)
    headings = []
    doc.css('h1, h2, h3').each do |heading|
      text = heading.text.strip
      headings << text unless text.empty?
    end
    headings.take(20) # Limit to first 20 headings
  end

  def extract_paragraphs(doc)
    paragraphs = []
    doc.css('p').each do |para|
      text = para.text.strip
      paragraphs << text if text.length > 20 # Only meaningful paragraphs
    end
    paragraphs.take(30) # Limit to first 30 paragraphs
  end

  def extract_social_media_links(doc)
    social_media = {
      linkedin: nil,
      facebook: nil,
      twitter: nil,
      instagram: nil,
      youtube: nil
    }

    # 1. Check meta tags first (og:social, twitter:social, etc.)
    meta_social_patterns = {
      linkedin: /linkedin\.com\/(company|school|in|showcase)\//i,
      facebook: /facebook\.com\/[^\/]+\/?$/i,
      twitter: /(twitter\.com|x\.com)\/[^\/]+\/?$/i,
      instagram: /instagram\.com\/[^\/]+\/?$/i,
      youtube: /youtube\.com\/(channel|c|user|@)/i
    }

    doc.css('meta').each do |meta|
      content = meta['content'] || meta['value']
      next unless content

      meta_social_patterns.each do |platform, pattern|
        if content =~ pattern && social_media[platform].nil?
          social_media[platform] = normalize_social_url(content, platform)
        end
      end
    end

    # 2. Check all links (a[href]) - footer, header, body
    doc.css('a[href]').each do |link|
      href = link['href']
      next if href.nil? || href.to_s.strip.empty?

      # Normalize relative URLs
      href = normalize_social_url(href, nil)

      # Check for LinkedIn
      if href =~ /linkedin\.com\/(company|school|showcase)\/([^\/\?]+)/i && social_media[:linkedin].nil?
        social_media[:linkedin] = href.split('?').first
      elsif href =~ /linkedin\.com\/in\/([^\/\?]+)/i && social_media[:linkedin].nil?
        # Personal LinkedIn - still capture it
        social_media[:linkedin] = href.split('?').first
      end

      # Check for Facebook
      if href =~ /facebook\.com\/([^\/\?]+)/i && social_media[:facebook].nil?
        # Exclude generic facebook.com or facebook.com/sharer
        unless href =~ /facebook\.com\/(sharer|plugins|dialog)/i
          social_media[:facebook] = href.split('?').first
        end
      end

      # Check for Twitter/X
      if href =~ /(twitter\.com|x\.com)\/([^\/\?]+)/i && social_media[:twitter].nil?
        # Exclude intent, share, and other functional URLs
        unless href =~ /(intent|share|oauth)/i
          social_media[:twitter] = href.split('?').first
        end
      end

      # Check for Instagram
      if href =~ /instagram\.com\/([^\/\?]+)/i && social_media[:instagram].nil?
        # Exclude explore, p/, tv/, etc.
        unless href =~ /instagram\.com\/(p|tv|reel|explore|accounts)/i
          social_media[:instagram] = href.split('?').first
        end
      end

      # Check for YouTube
      if href =~ /youtube\.com\/(channel|c|user|@)\/([^\/\?]+)/i && social_media[:youtube].nil?
        social_media[:youtube] = href.split('?').first
      elsif href =~ /youtube\.com\/([^\/\?]+)$/i && social_media[:youtube].nil?
        # Custom YouTube URLs
        social_media[:youtube] = href.split('?').first
      end
    end

    # 3. Check for social links in class/id attributes (icon links without text)
    doc.css('[class*="linkedin"], [id*="linkedin"], [href*="linkedin"]').each do |elem|
      if elem['href'] && elem['href'] =~ /linkedin\.com/i && social_media[:linkedin].nil?
        href = normalize_social_url(elem['href'], :linkedin)
        social_media[:linkedin] = href if href =~ /linkedin\.com\/(company|school|showcase|in)\//i
      end
    end

    doc.css('[class*="facebook"], [id*="facebook"], [href*="facebook"]').each do |elem|
      if elem['href'] && elem['href'] =~ /facebook\.com/i && social_media[:facebook].nil?
        href = normalize_social_url(elem['href'], :facebook)
        social_media[:facebook] = href unless href =~ /facebook\.com\/(sharer|plugins|dialog)/i
      end
    end

    doc.css('[class*="twitter"], [class*="x-twitter"], [id*="twitter"], [href*="twitter"], [href*="x.com"]').each do |elem|
      if elem['href'] && elem['href'] =~ /(twitter\.com|x\.com)/i && social_media[:twitter].nil?
        href = normalize_social_url(elem['href'], :twitter)
        social_media[:twitter] = href unless href =~ /(intent|share|oauth)/i
      end
    end

    doc.css('[class*="instagram"], [id*="instagram"], [href*="instagram"]').each do |elem|
      if elem['href'] && elem['href'] =~ /instagram\.com/i && social_media[:instagram].nil?
        href = normalize_social_url(elem['href'], :instagram)
        social_media[:instagram] = href unless href =~ /instagram\.com\/(p|tv|reel|explore|accounts)/i
      end
    end

    doc.css('[class*="youtube"], [id*="youtube"], [href*="youtube"]').each do |elem|
      if elem['href'] && elem['href'] =~ /youtube\.com/i && social_media[:youtube].nil?
        href = normalize_social_url(elem['href'], :youtube)
        social_media[:youtube] = href if href =~ /youtube\.com\/(channel|c|user|@)/i
      end
    end

    # Return cleaned up hash with only found links
    social_media.transform_values { |v| v&.to_s&.strip&.empty? ? nil : v }
  end

  def normalize_social_url(url, platform)
    return nil if url.nil? || url.to_s.strip.empty?

    url = url.to_s.strip

    # Handle relative URLs
    if url.start_with?('//')
      url = 'https:' + url
    elsif url.start_with?('/')
      # Relative path - prepend base domain based on platform
      case platform
      when :linkedin
        url = 'https://linkedin.com' + url
      when :facebook
        url = 'https://facebook.com' + url
      when :twitter
        url = 'https://twitter.com' + url
      when :instagram
        url = 'https://instagram.com' + url
      when :youtube
        url = 'https://youtube.com' + url
      end
    elsif !url.start_with?('http')
      url = 'https://' + url
    end

    # Clean up URL
    url = url.split('#').first # Remove hash fragments
    url = url.gsub(/\?.*$/, '') # Remove query params for cleaner URLs
    url
  end

  def extract_links(doc)
    links = []
    doc.css('a[href]').each do |link|
      href = link['href']
      text = link.text.strip

      # Look for social media and important links
      if href =~ /linkedin\.com|facebook\.com|twitter\.com|instagram\.com|youtube\.com/i ||
         text =~ /about|contact|location|address/i
        links << { text: text, href: href }
      end
    end
    links.take(20)
  end

  def extract_contact_info(doc)
    text = doc.text

    {
      emails: text.scan(/[\w\.-]+@[\w\.-]+\.\w+/).uniq.take(5),
      phones: text.scan(/(?:\+\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/).uniq.take(5),
      addresses: extract_addresses(doc)
    }
  end

  def extract_addresses(doc)
    addresses = []

    # Look for address patterns
    doc.css('[itemtype*="PostalAddress"], address, .address, #address').each do |elem|
      text = elem.text.strip
      addresses << text unless text.empty?
    end

    addresses.take(3)
  end
end
