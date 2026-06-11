#!/usr/bin/env bash

set -euo pipefail


ENUMS=("abstract" "anime" "city" "minimalist" "landscape" "plants" "person" "space")


if [[ -z "${1:-}" ]]; then
    echo "Usage: $0 <image_path> [model]"
    exit 1
fi

SOURCE_IMG_PATH="$1"
MODEL="${2:-google/gemini-2.5-flash-lite}"
WALLPAPER_NAME="$(basename "$SOURCE_IMG_PATH")"
RESIZED_IMG_PATH="/tmp/quickshell/ai/wallpaper.jpg"


PROMPT="Classify this wallpaper into exactly one of the following categories: abstract, anime, city, minimalist, landscape, plants, person, space.
Output as JSON with a single key 'classification'. Plain JSON only, do not add explanation.
Wallpaper filename: $WALLPAPER_NAME"

mkdir -p "$(dirname "$RESIZED_IMG_PATH")"
magick "$SOURCE_IMG_PATH" -resize 200x -quality 50 "$RESIZED_IMG_PATH"

API_KEY=$(secret-tool lookup 'application' 'illogical-impulse' | jq -r '.apiKeys.openrouter')

if [[ -z "$API_KEY" || "$API_KEY" == "null" ]]; then
    echo "OpenRouter API key not found"
    exit 1
fi

# -------------------------
# BASE64 ENCODE
# -------------------------

if [[ "$(base64 --version 2>&1)" == *"FreeBSD"* ]]; then
    B64FLAGS="--input"
else
    B64FLAGS="-w0"
fi

B64DATA="$(base64 $B64FLAGS "$RESIZED_IMG_PATH")"
IMG_URL="data:image/jpeg;base64,$B64DATA"

# -------------------------
# PAYLOAD (STRUCTURED OUTPUTS)
# -------------------------

payload=$(jq -n \
  --arg model "$MODEL" \
  --arg prompt "$PROMPT" \
  --arg img "$IMG_URL" \
  '{
    model: $model,
    temperature: 0,
    messages: [
      {
        role: "user",
        content: [
          { type: "text", text: $prompt },
          { type: "image_url", image_url: { url: $img } }
        ]
      }
    ],
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "wallpaperClassification",
        strict: true,
        schema: {
          type: "object",
          properties: {
            classification: {
              type: "string",
              enum: ["abstract","anime","city","minimalist","landscape","plants","person","space"]
            }
          },
          required: ["classification"],
          additionalProperties: false
        }
      }
    }
  }'
)

response=$(curl -s https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -H "HTTP-Referer: quickshell" \
  -H "X-Title: Quickshell Wallpaper AI" \
  -d "$payload"
)

RAW_CONTENT=$(echo "$response" | jq -r '.choices[0].message.content' 2>/dev/null || echo "")
RESULT=$(echo "$RAW_CONTENT" | jq -r '.classification' 2>/dev/null || echo "$RAW_CONTENT")

echo "$RESULT"
