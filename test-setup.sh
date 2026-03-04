#!/usr/bin/env bash
set -euo pipefail

echo "=== Tutoring setup: Ollama + Llama 3.2 3B Instruct on Pi 5 with Podman ==="

# 1. Install Podman if missing
if ! command -v podman &> /dev/null; then
    echo "Installing Podman..."
    sudo apt update
    sudo apt install -y podman
fi

# 2. Create persistent storage folders
mkdir -p ~/ollama/models
mkdir -p ~/ollama/config

# 3. Create strong kid-tutor Modelfile
cat > ~/ollama/config/Modelfile-kid-tutor << 'EOF'
FROM llama3.2:3b-instruct

SYSTEM """
You are "Science & Maths Buddy", a kind, patient, fun tutor ONLY for children up to 14 years old.
Rules you MUST follow every time:
- Use very simple words and short sentences.
- Give fun examples: animals, toys, food, games, sports.
- Explain ONE small step at a time.
- NEVER give the full answer immediately — always ask a question so the child can think.
- If stuck, give ONE tiny hint.
- ONLY talk about science or maths school topics.
- If question is off-topic, unsafe, personal, or mean: reply "Let's keep it to fun science or maths — what's your question?"
- Be super encouraging: say "Great try!", "You're doing brilliantly!", "We can figure this out together!"
- End most replies with a question to check understanding.
"""
EOF

echo "Custom Modelfile created."

# 4. Build the image (only once or when updating Ollama base)
echo "Building Ollama image with Llama 3.2 3B Instruct..."
podman build -t ollama-tutor-pi -f Dockerfile .

# 5. Run the container (persistent, rootless, localhost-only)
if podman ps -q -f name=ollama-tutor > /dev/null; then
    echo "Stopping old container..."
    podman stop ollama-tutor && podman rm ollama-tutor
fi

echo "Starting tutoring container..."
podman run -d \
    --name ollama-tutor \
    -v ~/ollama/models:/root/.ollama \
    -p 127.0.0.1:11434:11434 \
    --restart unless-stopped \
    --read-only \
    --tmpfs /tmp:size=256m \
    ollama-tutor-pi

# Wait for startup
sleep 10

# 6. Create the custom tutor model inside the container
echo "Creating custom 'kid-tutor' model..."
podman cp ~/ollama/config/Modelfile-kid-tutor ollama-tutor:/tmp/Modelfile-kid-tutor
podman exec ollama-tutor ollama create kid-tutor -f /tmp/Modelfile-kid-tutor

echo ""
echo "Tutoring setup ready!"
echo ""
echo "=== How to use ==="
echo "Interactive chat (best for testing):"
echo "  podman exec -it ollama-tutor ollama run kid-tutor"
echo ""
echo "One-shot API test from your Pi terminal:"
echo "  curl http://127.0.0.1:11434/api/chat -d '{\"model\":\"kid-tutor\",\"messages\":[{\"role\":\"user\",\"content\":\"How do I add 1/4 and 1/2?\"}],\"stream\":false}' | jq -r '.message.content'"
echo ""

# 7. Quick automated tests with sample prompts
echo "Running 5 test prompts for tutoring quality..."

TEST_PROMPTS=(
    "How do I add 1/4 and 1/2?"
    "Why does a ball fall down when I drop it?"
    "Solve this: 3x + 7 = 19"
    "What is the difference between ice, water and steam?"
    "I don't understand why we multiply when finding area. I'm stupid."
)

for prompt in "${TEST_PROMPTS[@]}"; do
    echo ""
    echo "Test prompt: $prompt"
    echo "----------------------------------------"
    RESPONSE=$(curl -s http://127.0.0.1:11434/api/chat -d '{
      "model": "kid-tutor",
      "messages": [{"role": "user", "content": "'"$prompt"'"}],
      "stream": false
    }' | jq -r '.message.content // .error // "No response"')
    echo "$RESPONSE"
    echo "----------------------------------------"
done

echo ""
echo "Done! Review the responses above — they should be simple, guiding, encouraging, and safe."
echo "If happy, integrate the API[](http://127.0.0.1:11434) into your Python tutoring portal."

