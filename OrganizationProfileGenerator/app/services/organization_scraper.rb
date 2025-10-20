require 'httparty'
require 'nokogiri'

class OrganizationScraper
  def initialize(url)
    @url = normalize_url(url)
  end

  def scrape
    Rails.logger.info "Scraping URL: #{@url}"

    begin
      response = HTTParty.get(@url,
        timeout: 30,
        follow_redirects: true,
        headers: {
          'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
      )

      if response.success?
        parse_content(response.body, response.headers['content-type'])
      else
        raise "Failed to fetch website: HTTP #{response.code}"
      end
    rescue => e
      Rails.logger.error "Scraping error: #{e.message}"
      raise "Unable to scrape website: #{e.message}"
    end
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

    # Remove script and style elements
    doc.css('script, style, nav, footer, iframe').remove

    # Extract text content
    {
      title: extract_title(doc),
      meta_description: extract_meta_description(doc),
      headings: extract_headings(doc),
      paragraphs: extract_paragraphs(doc),
      links: extract_links(doc),
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
