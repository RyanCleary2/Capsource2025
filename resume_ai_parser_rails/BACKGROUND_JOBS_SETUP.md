# Background Jobs Setup

## Overview

The AI resume processing has been moved to background jobs to prevent the application from slowing down or stopping while processing resumes. This follows the CTO's requirement to move AI processing into a separate process pipeline.

## What Was Changed

### 1. Created Background Job
**File:** `app/jobs/resume_processing_job.rb`

This job handles:
- PDF parsing using `ResumeParser`
- AI enhancement using `OpenaiProfileEnhancer`
- Storing results in Rails cache
- Error handling and cleanup

The job runs in a separate process/thread, so the main application remains responsive.

### 2. Updated Controller
**File:** `app/controllers/resumes_controller.rb`

Changes:
- `process_resume` method now enqueues a background job instead of processing synchronously
- Saves uploaded PDF to persistent storage (`tmp/uploads/`)
- Sets processing status to 'processing'
- Redirects immediately to result page

- `result` method now checks processing status:
  - `processing` - Shows loading screen with auto-refresh
  - `completed` - Shows the profile data
  - `failed` - Shows error message

### 3. Updated View
**File:** `app/views/resumes/result.html.erb`

Added:
- Loading screen with spinner when processing
- Error screen if processing fails
- Auto-refresh every 3 seconds while processing

## How It Works

1. **User uploads PDF**
   - File is saved to `tmp/uploads/`
   - Status set to 'processing'
   - Background job is enqueued
   - User redirected to result page

2. **Background job processes**
   - Runs in separate thread/process
   - Parses PDF
   - Calls OpenAI API
   - Stores result in cache
   - Sets status to 'completed' or 'failed'

3. **User sees result**
   - While processing: Loading screen with auto-refresh
   - When complete: Full profile data
   - If failed: Error message with retry option

## Benefits

- **No blocking**: Main application stays responsive
- **No slowdowns**: AI processing doesn't affect other users
- **Better UX**: User sees immediate feedback with loading screen
- **Scalable**: Can handle multiple concurrent uploads

## Running the Application

The application uses Rails' default `:async` adapter for Active Job, which runs jobs in a background thread pool. No additional setup is required for development.

Just start the Rails server normally:

```bash
./bin/dev
# or
rails server
```

## For Production (Future)

For production, consider using a more robust job queue like:
- **Sidekiq** (recommended) - Fast, efficient, Redis-backed
- **Delayed Job** - Simple, database-backed
- **Resque** - Redis-backed

To use Sidekiq:
1. Add to Gemfile: `gem 'sidekiq'`
2. Configure in `config/application.rb`: `config.active_job.queue_adapter = :sidekiq`
3. Run Sidekiq process: `bundle exec sidekiq`

## Testing

To test the background job:

1. Upload a resume PDF
2. You should see the loading screen immediately
3. The page will auto-refresh every 3 seconds
4. Once processing completes, the profile data appears

## Troubleshooting

**Job not running:**
- Check `log/development.log` for errors
- Ensure the job is being enqueued (look for "Enqueued ResumeProcessingJob")

**Processing stuck:**
- Check if there are any errors in the job
- Look for the job in the logs
- Clear cache and try again: `Rails.cache.clear`

**File upload issues:**
- Ensure `tmp/uploads/` directory exists and is writable
- Check file permissions

## Files Modified

1. `app/jobs/resume_processing_job.rb` - NEW
2. `app/controllers/resumes_controller.rb` - MODIFIED
3. `app/views/resumes/result.html.erb` - MODIFIED
