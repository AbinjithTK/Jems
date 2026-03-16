# Jumns ADK Agent Service — Google Cloud Run
# Serves REST chat + WebSocket bidi-streaming with Gemini via Vertex AI

FROM python:3.12-slim

WORKDIR /app

# System deps for numpy/faiss
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt uvicorn[standard]

COPY app/ ./app/

# Cloud Run uses PORT env var (default 8080)
ENV PORT=8080
ENV PYTHONUNBUFFERED=1

# Use Vertex AI instead of AI Studio API key — ADK/google-genai reads these
ENV GOOGLE_GENAI_USE_VERTEXAI=TRUE
ENV GOOGLE_CLOUD_LOCATION=us-central1

EXPOSE 8080

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
