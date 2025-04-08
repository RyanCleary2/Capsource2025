# CapChat – AI Career & Project Coach for CapSource

CapChat is a conversational AI assistant developed for CapSource to help students, educators, and industry professionals navigate career opportunities, discover real-world projects, and engage with mentorship. The chatbot combines natural language understanding, context-awareness, and feedback systems to deliver accurate and personalized assistance.

---

## Features

### Contextual Understanding
- Intent recognition using OpenAI Embeddings
- Named Entity Recognition (NER) powered by spaCy
- Spelling correction via TextBlob
- Sentiment analysis to tailor response tone
- Clarifying prompts for vague or ambiguous input
- Smart query rewriting to improve accuracy and clarity

### Role-Based Personalization
- Distinct conversational flows for:
  - Students: project discovery, mentorship, internships
  - Academic partners: course integration, curriculum design
  - Industry professionals: talent sourcing, project collaboration

### Memory Handling
- Session-based memory for short-term context using PostgreSQL
- User profile memory for long-term personalization using MongoDB
- Past user interactions are embedded in follow-up prompts for continuity

### Retrieval-Augmented Generation (RAG)
- Combines GPT-4o with indexed CapSource knowledge
- Accesses FAQs, project guides, mentorship programs, and user-specific data
- Uses chunked knowledge base and vector similarity for relevant responses

### Feedback and Optimization Loop
- Explicit feedback: thumbs up/down with optional comments
- Implicit feedback: drop-off detection, message rephrasing
- A/B testing to compare prompt and response strategies
- Automated feedback ingestion for iterative improvements

---

## Architecture Overview

```
User Input
   │
   ▼
Preprocessing → Intent & NER Detection → Memory Lookup
   │                                    ↘
   └─────→ RAG: GPT-4o + Context Chunks (User Role + History + CapSource Data)
                                         ↓
                            Response Generation & Clarification
                                         ↓
                             Feedback Collection (Explicit + Implicit)
```

---

## Code Highlights

Implemented in `ragFirstDraft.py`:
- Functions for text cleaning, lemmatization, spelling correction
- Embedding-based intent detection using OpenAI's `text-embedding-ada-002`
- Vague input detection and fallback responses
- Named entity extraction using spaCy
- Sentiment classification with TextBlob
- Full processing pipeline in `process_user_input()`

---

## Frontend

Available as a responsive widget in `capchatTest.html`:
- Chat bubble toggle and close functionality
- Role-based onboarding with dropdown selector
- Dynamic message rendering based on selected role
- Styled with a minimal CSS layout using gradient headers and structured chat messages

---

## Training and Testing

### Data Sources
- Internal CapSource knowledge base (projects, roles, mentorship)
- Job boards and career platforms (LinkedIn, Indeed, Coursera)
- Conversation logs and user-submitted feedback

### Training Techniques
- Real user interactions categorized for NLP modeling
- Multi-turn dialogues and edge case examples for robustness
- Few-shot prompting and scenario-based training

Refer to:
- `Chatbot trainining convos.pdf` for conversation categories and examples
- `Train AI chatbot.docx` for context-awareness and edge case handling

---

## Setup and Usage

### Prerequisites
- Python 3.8+
- OpenAI API key
- MongoDB and PostgreSQL instances
- Required libraries: `openai`, `spacy`, `textblob`, `scikit-learn`, `numpy`

### Installation

```bash
pip install openai spacy textblob numpy scikit-learn
python -m textblob.download_corpora
python -m spacy download en_core_web_sm
```

### Running the Pipeline

```python
from ragFirstDraft import process_user_input
response = process_user_input("I need help with data science projects")
print(response)
```

---

## Known Issues

- Abrupt chat terminations in certain flows
- Incorrect link redirects (e.g., to `capstonesource.com`)
- Premature messaging about contact follow-up without collecting user information

Details are documented in `Train AI chatbot.docx`.

---

## Testing and Feedback Strategy

CapChat incorporates structured A/B testing and feedback analysis:
- Control vs. test groups with prompt variants
- Metrics include session duration, engagement rates, and user sentiment
- Negative feedback is flagged and used for training refinements

See `CapChat - Sprint6.docx` and `Sprint7.docx` for implementation plans and evaluation results.

---

## Resources

- `ragFirstDraft.py` – NLP and response pipeline
- `capchatTest.html` – Frontend interface
- `CapChat - Sprint6.docx` – Feedback loop and memory structure
- `CapChat - Sprint7.docx` – NLP pipeline and enhancements
- `RAG Mockup.pdf` – Architecture and system prompt design

---

## Contact

Developed by the CapSource team.  
For support or contribution inquiries, email: [support@capsource.io](mailto:support@capsource.io)