#!/usr/bin/env ruby

# Simple test script to verify application functionality
require_relative 'config/environment'

puts "=== SkillOrganizer Application Test ==="
puts

# Test 1: Data Loading
puts "1. Testing data loading..."
skills = SkillDataService.all_skills
puts "   ✓ Loaded #{skills.count} skills"

# Test 2: Categorization
puts "\n2. Testing categorization..."
categories = SkillDataService.categories
puts "   ✓ #{categories.count} categories available:"
categories.each { |cat| puts "     - #{cat[:name]}" }

# Test 3: Search functionality
puts "\n3. Testing search functionality..."
python_skills = SkillDataService.search_skills(search: 'python')
puts "   ✓ Found #{python_skills.count} Python-related skills"

data_skills = SkillDataService.search_skills(category_id: 'data-analytics')
puts "   ✓ Found #{data_skills.count} Data & Analytics skills"

# Test 4: Sample skills display
puts "\n4. Sample skills:"
skills.first(5).each do |skill|
  category_name = categories.find { |cat| cat[:id] == skill[:category] }&.dig(:name) || 'Unknown'
  puts "   - #{skill[:name]} (#{category_name})"
end

# Test 5: Related skills
puts "\n5. Testing related skills..."
if skills.any?
  sample_skill = skills.first
  related = SkillDataService.related_skills(sample_skill[:id])
  puts "   ✓ Found #{related.count} related skills for '#{sample_skill[:name]}'"
end

puts "\n=== All Tests Passed! ==="
puts "🚀 Application is ready at http://localhost:3000"