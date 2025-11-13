#!/bin/bash

# CapSource Profile Generator - Google Cloud Run Deployment Script
# Service ID: capsource-profile-builder

set -e

echo "🚀 CapSource Profile Generator - Cloud Run Deployment"
echo "======================================================"
echo ""

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-resume-parser-359702366805}"
SERVICE_NAME="capsource-profile-builder"
REGION="${GCP_REGION:-us-central1}"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "📋 Deployment Configuration:"
echo "   Project ID: ${PROJECT_ID}"
echo "   Service Name: ${SERVICE_NAME}"
echo "   Region: ${REGION}"
echo "   Image: ${IMAGE_NAME}"
echo ""

# Check for required tools
echo "🔍 Checking for required tools..."

if ! command -v gcloud &> /dev/null; then
    echo "❌ Google Cloud CLI (gcloud) is not installed."
    echo ""
    echo "Please install it from: https://cloud.google.com/sdk/docs/install"
    echo "Or run: brew install --cask google-cloud-sdk"
    echo ""
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "⚠️  Docker is not installed."
    echo ""
    echo "You have two options:"
    echo "1. Install Docker Desktop: https://www.docker.com/products/docker-desktop"
    echo "2. Use Cloud Build (recommended - no local Docker needed)"
    echo ""
    read -p "Use Cloud Build instead of local Docker? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    USE_CLOUD_BUILD=true
else
    echo "✅ Docker is installed"
    USE_CLOUD_BUILD=false
fi

echo "✅ gcloud is installed"
echo ""

# Authenticate with Google Cloud
echo "🔐 Checking Google Cloud authentication..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo "Please authenticate with Google Cloud:"
    gcloud auth login
fi

# Set project
echo "📦 Setting Google Cloud project..."
gcloud config set project ${PROJECT_ID}

# Enable required APIs
echo "🔌 Enabling required Google Cloud APIs..."
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com

# Read master key
if [ ! -f "config/master.key" ]; then
    echo "❌ config/master.key not found!"
    exit 1
fi
MASTER_KEY=$(cat config/master.key)

# Read OpenAI API key
if [ ! -f ".env" ]; then
    echo "❌ .env file not found!"
    exit 1
fi
OPENAI_API_KEY=$(grep OPENAI_API_KEY .env | cut -d '=' -f2)
OPENAI_MODEL=$(grep OPENAI_MODEL .env | cut -d '=' -f2 || echo "gpt-4o-mini")

if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ OPENAI_API_KEY not found in .env file!"
    exit 1
fi

echo "✅ Configuration loaded"
echo ""

# Build the image
if [ "$USE_CLOUD_BUILD" = true ]; then
    echo "🏗️  Building image with Cloud Build..."
    gcloud builds submit --tag ${IMAGE_NAME}
else
    echo "🏗️  Building Docker image locally..."
    docker build -t ${IMAGE_NAME} .
    
    echo "📤 Pushing image to Google Container Registry..."
    docker push ${IMAGE_NAME}
fi

echo ""
echo "🚀 Deploying to Cloud Run..."
gcloud run deploy ${SERVICE_NAME} \
    --image ${IMAGE_NAME} \
    --platform managed \
    --region ${REGION} \
    --allow-unauthenticated \
    --set-env-vars "RAILS_MASTER_KEY=${MASTER_KEY},OPENAI_API_KEY=${OPENAI_API_KEY},OPENAI_MODEL=${OPENAI_MODEL},RAILS_LOG_TO_STDOUT=true,RAILS_SERVE_STATIC_FILES=true" \
    --memory 2Gi \
    --cpu 2 \
    --timeout 300 \
    --max-instances 10 \
    --min-instances 0 \
    --port 80

echo ""
echo "✅ Deployment complete!"
echo ""

# Get the service URL
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --region ${REGION} --format 'value(status.url)')
echo "🌐 Your application is live at:"
echo "   ${SERVICE_URL}"
echo ""
echo "📝 Next steps:"
echo "   1. Visit ${SERVICE_URL} to test your application"
echo "   2. View logs: gcloud run logs read --service=${SERVICE_NAME} --region=${REGION}"
echo "   3. Monitor: https://console.cloud.google.com/run/detail/${REGION}/${SERVICE_NAME}"
echo ""
