import re
import spacy
import openai
from textblob import TextBlob
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np

openai.api_key = "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"

# Load spaCy's English model
nlp = spacy.load("en_core_web_sm")

# Predefined intents for CapChat
PREDEFINED_INTENTS = {
    "find_mentor": "How do I find a mentor?",
    "project_matching": "What projects are available?",
    "internship_search": "Are there internships for marketing students?",
}

# Fallback clarification prompts
CLARIFICATION_RESPONSES = {
    "unknown_intent": "Can you clarify what you're looking for? For example, are you interested in mentorship, internships, or projects?",
    "vague_input": "Could you tell me a bit more so I can help? For instance, what role or industry are you focused on?"
}

# Function to clean text
def clean_text(text):
    text = text.lower().strip()
    text = re.sub(r'[^a-zA-Z0-9\s]', '', text)
    text = re.sub(r'\s+', ' ', text)
    return text

# Spell correction using TextBlob
def correct_spelling(text):
    return str(TextBlob(text).correct())

# Extract named entities
def extract_entities(text):
    doc = nlp(text)
    return {ent.label_: ent.text for ent in doc.ents}

# Lemmatization
def preprocess_text(text):
    doc = nlp(text)
    return " ".join([token.lemma_ for token in doc if not token.is_stop])

# Get embedding from OpenAI
def get_embedding(text):
    # Guarantee API key is set, even if script was reloaded or context lost
    if not openai.api_key:
        openai.api_key = "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"

    print(" Using key starting with:", openai.api_key[:10])
    response = openai.Embedding.create(input=text, model="text-embedding-ada-002")
    return response['data'][0]['embedding']


# Detect user intent
def detect_intent(processed_text):
    if not processed_text:
        print("Empty input to detect_intent")
        return "unknown_intent"

    user_embedding = np.array(get_embedding(processed_text)).reshape(1, -1)
    best_match, best_score = None, -1

    for intent, example in PREDEFINED_INTENTS.items():
        intent_embedding = np.array(get_embedding(example)).reshape(1, -1)
        score = cosine_similarity(user_embedding, intent_embedding)[0][0]
        if score > best_score:
            best_score = score
            best_match = intent if score > 0.75 else "unknown_intent"

    return best_match

# Check for vague queries (simple heuristic)
def is_vague_input(text):
    vague_keywords = ["help", "assist", "support", "need help", "what now"]
    return len(text.split()) < 5 or any(kw in text.lower() for kw in vague_keywords)

# Basic sentiment analysis using TextBlob
def detect_sentiment(text):
    return TextBlob(text).sentiment.polarity

# Main pipeline
def process_user_input(user_input):
    print("🔹 Original Input:", user_input)

    # Step 1: Correct spelling
    corrected = correct_spelling(user_input)

    # Step 2: Clean text
    cleaned = clean_text(corrected)

    # Step 3: Extract entities
    entities = extract_entities(cleaned)

    # Step 4: Preprocess for intent detection
    lemmatized = preprocess_text(cleaned)

    # Step 5: Detect sentiment
    sentiment_score = detect_sentiment(user_input)
    sentiment = "positive" if sentiment_score > 0.2 else "negative" if sentiment_score < -0.2 else "neutral"

    # Step 6: Check for vague input
    if is_vague_input(user_input):
        return {
            "clarification_needed": True,
            "response": CLARIFICATION_RESPONSES["vague_input"],
            "sentiment": sentiment
        }

    # Step 7: Intent detection
    intent = detect_intent(lemmatized)
    if intent == "unknown_intent":
        return {
            "clarification_needed": True,
            "response": CLARIFICATION_RESPONSES[intent],
            "entities": entities,
            "sentiment": sentiment
        }

    # Final structured response
    return {
        "clarification_needed": False,
        "corrected_text": corrected,
        "cleaned_text": cleaned,
        "lemmatized_text": lemmatized,
        "entities": entities,
        "intent": intent,
        "sentiment": sentiment,
        "response": f"Intent recognized: {intent}. Let me help you with that!"
    }
