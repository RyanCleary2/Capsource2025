
# CapChat API Documentation

## Overview

CapChat is an AI-powered chatbot built for CapSource to support students, educators, and industry partners with project-based learning, mentorship, and career development. This documentation outlines the API logic, input expectations, and response formats that enable intelligent, context-aware conversations.

---

## Core Logic Flow

### 1. **Preprocessing & NLP Pipeline**
CapChat uses multiple NLP steps before generating a response:

- **Text Cleaning**: Lowercase conversion, removal of special characters.
- **Tokenization & Lemmatization**: Words are broken into tokens and reduced to their root forms.
- **Named Entity Recognition (NER)**: Extracts keywords such as industries, roles, companies, and locations.
- **Intent Recognition**: Maps user inputs to predefined intent categories using OpenAI Embeddings.
- **Spell Correction**: Uses `TextBlob` to fix typos before analysis.
- **Sentiment Analysis**: Adjusts tone and follow-up questions based on user sentiment.

---

## Contextual Memory Logic

### A. **Session-Based Memory (Short-Term)**
- Stores 5–10 previous interactions in a session (e.g., via PostgreSQL).
- Enables continuity across multi-turn conversations.

### B. **User Profile-Based Memory (Long-Term)**
- Stores user roles, preferences, past queries.
- Used for personalization in future sessions (e.g., with MongoDB).

---

## Input Format

CapChat expects a JSON structure in API calls like:

```json
{
  "user_id": "user_123",
  "role": "Student",
  "query": "I need help with finance projects",
  "chat_history": [
    {"role": "user", "content": "Tell me about CapSource projects"},
    {"role": "assistant", "content": "Sure! Are you interested in a specific area or industry?"}
  ]
}
```

### Fields:

| Field         | Type    | Description |
|---------------|---------|-------------|
| `user_id`     | string  | Unique identifier for the user |
| `role`        | string  | User role: Student, Academic, Industry |
| `query`       | string  | The current user input |
| `chat_history`| array   | Prior conversation exchanges for context retention |

---

## Response Format

Typical CapChat responses follow this structure:

```json
{
  "response": "Based on your interest in finance projects, here are a few you might like...",
  "entities": {
    "industry": "finance"
  },
  "intent": "Project Matching",
  "follow_up_required": false
}
```

### Fields:

| Field              | Type    | Description |
|--------------------|---------|-------------|
| `response`         | string  | GPT-generated reply |
| `entities`         | object  | Extracted key info (industry, location, etc.) |
| `intent`           | string  | Detected intent from user query |
| `follow_up_required` | boolean | If more clarification is needed |

---

## Intent Categories

Some supported intents include:

- `Project Matching`
- `Career Advice`
- `Mentorship Inquiry`
- `Internship Help`
- `Platform Navigation`
- `General Inquiry`

---

## Contextual Slot Filling

If a query is vague or missing critical data, CapChat prompts follow-up questions:

> **User**: "I need help with a project"  
> **CapChat**: "Are you looking to join a project, or do you need help managing one?"

---

## Feedback System (Optional Extension)

### Explicit Feedback

```json
{
  "response_id": "res_789",
  "user_rating": "downvote",
  "comment": "Too generic",
  "timestamp": "2025-04-03T13:20:00Z"
}
```

### Implicit Feedback

Tracked via:
- Conversation drop-offs
- Rephrased queries
- Session length & engagement metrics

---

## Error Handling & Edge Cases

CapChat gracefully handles edge cases by:
- Asking clarifying questions for vague inputs
- Detecting invalid links (prevents misdirection to unrelated sites)
- Redirecting to human support if no resolution is possible

---

## Example API Call Structure

```json
{
  "system_prompt": "You are CapChat, an expert AI assistant for CapSource. Provide detailed, helpful responses for students, educators, and industry professionals.",
  "user_prompt": "What are some projects in data analytics?",
  "chat_history": [...],
  "user_profile": {
    "role": "Student",
    "preferences": ["analytics", "mentorship"]
  }
}
```

---

## Continuous Learning Pipeline

- User feedback loop (thumbs up/down + optional comments)
- Human moderation of edge cases
- Periodic fine-tuning and A/B testing
- Smart query rewriting for vague inputs

---

## A/B Testing Strategy

- Control Group (existing system) vs. Test Group (new logic)
- Track performance on:
  - Clarification success
  - User satisfaction
  - Query rephrasing rates
- Implement best-performing logic system-wide
