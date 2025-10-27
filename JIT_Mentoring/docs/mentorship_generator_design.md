# Mentorship Curriculum Generator — Design & Prompt Specification

Last updated: 2025-10-08

This document describes the Mentorship Curriculum Generator: the product goal, high-level architecture, data flow, API/endpoint designs, prompt templates and prompt engineering guidance, output schemas (text & JSON), testing guidance, security considerations, and scaling/operational notes.

## 1. Purpose and Overview

The Mentorship Curriculum Generator transforms a single user-provided mentee goal into a concise, actionable mentorship plan. The plan includes:
- Plan Title
- Pre-Meeting Assignment
- Meeting-by-meeting schedule (Date/Week, conversation starters/questions, action items, suggested deliverables)
- Summary and suggested follow-ups

Design assumptions:
- Input is intentionally minimal: a single free-text `mentee_goal` string.
- The model should infer duration and session frequency from the goal. If uncertain, default to 6 weeks with weekly sessions.
- The model should limit the total number of conversation questions across the whole plan to a maximum of 10.
- Output is human-readable text by default, rendered in the app via a lightweight formatting helper. Optionally, the generator can emit structured JSON for programmatic consumption.


## 2. High-level Architecture

- Frontend (ERB views in Rails): a minimal form accepting `mentee_goal` → POST to controller.
- Backend (Rails): `PlansController` receives the goal, constructs prompt, calls OpenAI Chat API using `OpenAI::Client`, extracts the text response, stores it in `@mentorship_plan`, renders `app/views/plans/result.html.erb` which uses `format_case_text` to present headings & lists.
- External service: OpenAI Chat API (gpt-4o-mini or other policy-compliant model).
- Optional: A background job processor to generate plans asynchronously if usage scales (Sidekiq/Active Job). Results can be saved in DB and made available via a job id.

Diagram (conceptual):

User -> Plans#index (form) -> PlansController#generate_mentorship_plan -> OpenAI Chat API -> PlansController (format & render) -> User


## 3. Data flow and contracts

Input: POST to `/generate_mentorship_plan` with params:
- mentee_goal: string (required)

Output (text mode): a single string (markdown-like) with headings. Example shape:

Plan Title: Short title

Pre-Meeting Assignment:
- 1–2 bullet items

Meeting 1 — Week X (Date):
- Questions: 2–4 questions
- Action Item: short sentence
- Deliverable: short sentence

... Meeting N

Summary: one paragraph


Optional JSON Schema (for programmatic mode):

{
  "title": "string",
  "pre_meeting_assignment": ["string"],
  "meetings": [
    {
      "week": "integer",
      "date": "YYYY-MM-DD (optional)",
      "questions": ["string"],
      "action_item": "string",
      "deliverable": "string"
    }
  ],
  "summary": "string",
  "inferred_duration_weeks": "integer",
  "inferred_session_frequency": "string"  // e.g., "weekly", "biweekly"
}


## 4. Prompt templates and engineering

Guiding principles:
- Keep the prompt deterministic about structure: headings, order, and caps.
- Move inference (duration/frequency) to the model but provide default fallback.
- Enforce the cap on total question count and require concise deliverables/action items.
- Prefer concise, asynchronous-friendly assignments.

Primary prompt (text output):

"""
Mentorship Plan Goal: "{{goal_statement}}"

Context and instructions:
- Infer an appropriate mentorship duration and session frequency from the goal. If unsure, default to a 6-week program with weekly sessions.
- Provide a brief Plan Title (under 8 words).
- Provide a clear Pre-Meeting Assignment (1–3 brief, actionable tasks).
- Divide the plan into meetings (determine N from the inferred duration/frequency). For each meeting provide:
  - Date or Week number
  - 1–4 guiding questions / conversation starters
  - A single concise action item for the mentee (1 sentence)
  - A suggested deliverable that demonstrates progress (1 short sentence)
- Use a total of no more than 10 questions across all meetings.
- Format response using these headings exactly: Plan Title, Pre-Meeting Assignment, Meeting 1..N, Summary.
- Keep each action item and deliverable concise and asynchronous-friendly.

Generate the mentorship plan now.
"""

Notes:
- If the model tends to exceed the question cap, follow-up prompts or a post-processor can truncate or re-balance questions across meetings.
- If you need structured JSON output, use a stricter prompt that asks the model to output only valid JSON conforming to the schema above and to respond with a single top-level JSON object.

JSON-mode prompt (recommended if programmatic consumers exist):
- First part of the prompt: same instructions + schema specification.
- Second part: instruction: "Respond with valid JSON only, no explanatory text."
- Consider small-model hallucination safeguards: ask the model to return null/empty strings if it cannot infer a date.

Example JSON-mode instruction tail:

"Respond with valid JSON only that conforms to this schema: <paste schema here>. Do not include any additional explanation or markdown. If a field cannot be inferred, use null."


## 5. Implementation notes (Rails-specific)

- Controller:
  - `PlansController#generate_mentorship_plan` constructs the prompt and calls OpenAI via `client.chat(parameters: {...})`.
  - Use a private helper method `generate_mentorship_plan_content_from_goal(client, goal_statement)` to encapsulate prompt and API call.
  - Rescue OpenAI errors and return nil to the caller; log errors.

- Views:
  - `app/views/plans/index.html.erb` should only accept `mentee_goal` and POST to the generate action.
  - `app/views/plans/result.html.erb` renders the generated string and uses a helper to convert heading markers (# / ##) to HTML tags if desired.

- Helpers:
  - Keep a small helper method to convert the model's markdown-like output into safe HTML. Ensure you sanitize rendered content if the output may contain user-supplied content.

- Testing:
  - Unit test the prompt generation method (string assertions or snapshot testing) to ensure structure is enforced.
  - Integration test: stub network calls to the OpenAI client and assert that the view renders the returned text.


## 6. Security and privacy

- Do NOT log raw user prompts or responses containing personal identifiable information (PII). Mask or redact sensitive fields in logs.
- Store API keys in environment variables (e.g., `ENV['OPENAI_API_KEY']`); do not commit them.
- Rate-limit generation endpoints to avoid abuse.
- If storing generated plans (or user goals), ensure database encryption or clear retention policies.
- Consider content moderation steps (pass outputs through a moderation endpoint) before displaying to other users when plans might contain sensitive career changes or personal data.


## 7. Cost, performance, and scaling

- Model choice matters: prefer smaller or cheaper models (gpt-4o-mini or others) for production if outputs match quality expectations.
- Add a queue & background job for heavy/large requests; return a job_id and poll for completion.
- Cache generated plans for the same goal text to avoid repeated API calls. Consider a TTL-based cache keyed by a hash of the input.
- Limit max_tokens in the chat call (e.g., 1800) and set temperature conservatively (0.4–0.8 depending on desired creativity).
- Monitor tokens usage and implement alerts for anomalous costs.


## 8. Observability and metrics

Track:
- Requests per minute to generation endpoint
- Average tokens per request
- Failure/error rates from OpenAI calls
- Latency for generation
- Cache hit rates (if using cache)


## 9. Testing and QA suggestions

- Synthetic tests: provide a suite of example goal inputs and assert the output meets expectations (contains Plan Title, Pre-Meeting Assignment, N meetings, and Summary).
- Human review: sample generated plans for correctness and utility; tune prompt iteratively.
- Edge-case tests: extremely short goals, contradictory goals, overly broad goals, and goals containing PII.


## 10. Future enhancements

- Add a "structured JSON" toggle and validation layer.
- Add user preferences: preferred session length, mentor availability windows, or desired deliverable types.
- Add user accounts and persistent plan storage with versioning.
- Add LLM-based rubric or scoring to rank plan quality automatically.
- Provide a "regenerate with constraints" flow to re-run prompt with narrower parameters (e.g., "shorter, fewer meetings").


---

Appendix: Example prompt (copyable):

```
Mentorship Plan Goal: "Become proficient in applied machine learning to win a summer internship"

Context and instructions:
- Infer duration & session frequency from the goal. Default to 6 weeks weekly if uncertain.
- Plan Title: one short line under 8 words.
- Pre-Meeting Assignment: 1-3 brief tasks.
- Meetings: provide Week/Date, 1-4 questions, one action item (brief), one deliverable (brief).
- Total questions across all meetings must not exceed 10.
- Format exactly with headings: Plan Title, Pre-Meeting Assignment, Meeting 1..N, Summary.

Generate the mentorship plan now.
```
