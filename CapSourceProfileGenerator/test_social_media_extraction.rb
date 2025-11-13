#!/usr/bin/env ruby
# Test script to verify social media extraction improvements

require 'nokogiri'
require_relative 'app/services/organization_scraper'

puts '══════════════════════════════════════════════════'
puts '   SOCIAL MEDIA EXTRACTION TEST'
puts '══════════════════════════════════════════════════'
puts ''

# Test HTML with various social media link patterns
test_html = <<~HTML
  <!DOCTYPE html>
  <html>
  <head>
    <meta property="og:url" content="https://linkedin.com/company/capsource-tech" />
    <title>CapSource Technologies</title>
  </head>
  <body>
    <header>
      <nav>
        <a href="/about">About</a>
        <a href="/contact">Contact</a>
      </nav>
    </header>

    <main>
      <h1>Welcome to CapSource Technologies</h1>
      <p>We build amazing software solutions for businesses.</p>
    </main>

    <footer>
      <div class="social-links">
        <!-- Icon-only links with classes -->
        <a href="https://linkedin.com/company/capsource-technologies" class="linkedin-icon" aria-label="LinkedIn">
          <svg>...</svg>
        </a>
        <a href="https://facebook.com/capsource" class="facebook-icon" aria-label="Facebook">
          <i class="fa fa-facebook"></i>
        </a>
        <a href="https://twitter.com/capsource_tech" class="twitter-icon" aria-label="Twitter">
          <i class="fa fa-twitter"></i>
        </a>
        <a href="https://instagram.com/capsourcetech" id="instagram-link">
          <img src="/instagram-icon.png" alt="Instagram">
        </a>
        <!-- Relative URL -->
        <a href="//youtube.com/c/capsource">YouTube</a>
      </div>

      <!-- Text links -->
      <div class="footer-social">
        <a href="https://linkedin.com/showcase/capsource-products">LinkedIn Showcase</a>
        <a href="https://x.com/capsource">Follow us on X</a>
      </div>
    </footer>
  </body>
  </html>
HTML

puts '📄 Testing HTML with various social media patterns:'
puts '  - Meta tags with LinkedIn'
puts '  - Icon-only links with classes'
puts '  - Relative URLs (//youtube.com)'
puts '  - Both twitter.com and x.com'
puts '  - Multiple LinkedIn formats'
puts ''

# Parse the HTML
doc = Nokogiri::HTML(test_html)

# Test the extraction method
scraper = OrganizationScraper.new('https://example.com')
social_media = scraper.send(:extract_social_media_links, doc)

puts '━━━ EXTRACTION RESULTS ━━━'
puts ''

if social_media[:linkedin]
  puts "✅ LinkedIn: #{social_media[:linkedin]}"
else
  puts "❌ LinkedIn: NOT FOUND"
end

if social_media[:facebook]
  puts "✅ Facebook: #{social_media[:facebook]}"
else
  puts "❌ Facebook: NOT FOUND"
end

if social_media[:twitter]
  puts "✅ Twitter: #{social_media[:twitter]}"
else
  puts "❌ Twitter: NOT FOUND"
end

if social_media[:instagram]
  puts "✅ Instagram: #{social_media[:instagram]}"
else
  puts "❌ Instagram: NOT FOUND"
end

if social_media[:youtube]
  puts "✅ YouTube: #{social_media[:youtube]}"
else
  puts "❌ YouTube: NOT FOUND"
end

puts ''
puts '━━━ TEST SUMMARY ━━━'

found_count = social_media.values.compact.count
total_count = 5

if found_count == total_count
  puts "🎉 SUCCESS! Found all #{total_count} social media links!"
elsif found_count > 0
  puts "⚠️  PARTIAL SUCCESS: Found #{found_count}/#{total_count} social media links"
else
  puts "❌ FAILED: No social media links found"
end

puts ''
puts '══════════════════════════════════════════════════'
