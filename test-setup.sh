#!/usr/bin/env bash
set -euo pipefail

echo "=== Tutoring setup: Llama-3.2-3B-Instruct (GGUF) on Pi 5 with Podman ==="

# 1. Install Podman + tools if missing
command -v podman >/dev/null 2>&1 || {
    echo "Installing Podman..."
    sudo apt update
    sudo apt install -y podman wget curl jq
}

# 2. Persistent storage
mkdir -p ~/ollama/models/blobs ~/ollama/config

# 3. Download GGUF file if not already present (Q5_K_M recommended for Pi 5)
GGUF_FILE="Llama-3.2-3B-Instruct-Q5_K_M.gguf"
GGUF_PATH="$HOME/ollama/models/blobs/$GGUF_FILE"

if [ ! -f "$GGUF_PATH" ]; then
    echo "Downloading Llama-3.2-3B-Instruct-Q5_K_M.gguf (~2.3 GB)..."
    wget -O "$GGUF_PATH" "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/$GGUF_FILE"
else
    echo "GGUF file already downloaded."
fi

# 4. Kid-tutor Modelfile (references the local GGUF file)
cat > ~/ollama/config/Modelfile-kid-tutor << EOF
FROM $GGUF_PATH

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
- Keep replies short (4-8 sentences max).
"""
EOF

# 5. Build minimal Ollama image (fast)
podman build -t ollama-tutor-pi - << 'EOF'
FROM docker.io/ollama/ollama:latest
EXPOSE 11434
CMD ["serve"]
EOF

# 6. (Re)start container
podman stop ollama-tutor >/dev/null 2>&1 || true
podman rm ollama-tutor >/dev/null 2>&1 || true

podman run -d \
    --name ollama-tutor \
    -v ~/ollama/models:/root/.ollama \
    -p 127.0.0.1:11434:11434 \
    --restart unless-stopped \
    --read-only \
    --tmpfs /tmp:size=256m \
    ollama-tutor-pi

echo "Waiting for Ollama server to start (30 seconds)..."
sleep 30

# 7. Create the custom kid-tutor model from GGUF + Modelfile
echo "Creating custom 'kid-tutor' model from GGUF..."
podman cp ~/ollama/config/Modelfile-kid-tutor ollama-tutor:/tmp/Modelfile-kid-tutor
podman exec ollama-tutor ollama create kid-tutor -f /tmp/Modelfile-kid-tutor

echo ""
echo "Setup finished! Model 'kid-tutor' is ready."
echo ""
echo "=== How to use ==="
echo "Interactive chat:"
echo "  podman exec -it ollama-tutor ollama run kid-tutor"
echo ""
echo "One-shot API test:"
echo "  curl http://127.0.0.1:11434/api/chat -d '{\"model\":\"kid-tutor\",\"messages\":[{\"role\":\"user\",\"content\":\"How do I add 1/4 and 1/2?\"}],\"stream\":false}' | jq -r '.message.content'"
echo ""

# 8. Run quick tests
echo "Running 5 test prompts..."

TEST_PROMPTS=(
    "How do I add 1/4 and 1/2?"
    "Why does a ball fall down when I drop it?"
    "Solve this: 3x + 7 = 19"
    "What is the difference between ice, water and steam?"
    "I don't understand why we multiply when finding area. I'm stupid."
)

for prompt in "${TEST_PROMPTS[@]}"; do
    echo ""
    echo "Test: $prompt"
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
echo "Done. If tests look good, integrate http://127.0.0.1:11434/api/chat into your Python portal."
echo "To change quantization (e.g., faster Q4_K_M or better Q6_K), download another GGUF from:"
echo "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF"

