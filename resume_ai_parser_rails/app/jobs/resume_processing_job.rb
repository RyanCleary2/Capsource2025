class ResumeProcessingJob < ApplicationJob
  queue_as :default

  # This job handles the PDF parsing and AI enhancement asynchronously
  # so the main application doesn't slow down or stop working while processing
  def perform(file_path, cache_key)
    Rails.logger.info "Starting resume processing job for cache key: #{cache_key}"

    begin
      # Parse the PDF
      parser = ResumeParser.new(file_path)
      profile_data = parser.parse_profile_data

      # Store the processed data in Rails cache
      Rails.cache.write(cache_key, profile_data, expires_in: 1.hour)

      # Mark processing as complete
      Rails.cache.write("#{cache_key}_status", 'completed', expires_in: 1.hour)

      Rails.logger.info "Resume processing completed successfully for cache key: #{cache_key}"

    rescue => e
      Rails.logger.error "Resume processing failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Mark processing as failed and store error message
      Rails.cache.write("#{cache_key}_status", 'failed', expires_in: 1.hour)
      Rails.cache.write("#{cache_key}_error", e.message, expires_in: 1.hour)

      # Re-raise the error so the job is marked as failed in the queue
      raise
    ensure
      # Clean up the temporary file
      File.delete(file_path) if File.exist?(file_path)
    end
  end
end
