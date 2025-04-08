import openai
openai.api_key = "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"  # Use your key

try:
    result = openai.Embedding.create(
        input="Hello world!",
        model="text-embedding-ada-002"
    )
    print("✅ It works!")
except Exception as e:
    print("❌ Error:", e)
