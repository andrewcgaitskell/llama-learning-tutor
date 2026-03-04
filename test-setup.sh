#!/usr/bin/env bash
set -euo pipefail

echo "=== Tutoring setup: Ollama + Llama 3.2 3B Instruct on Pi 5 (Podman) ==="

# 1. Install Podman if missing
command -v podman >/dev/null 2>&1 || {
    echo "Installing Podman..."
    sudo apt update
    sudo apt install -y podman
}

# 2. Persistent storage
mkdir -p ~/ollama/models ~/ollama/config

# 3. Kid-tutor Modelfile (strong guiding style)
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
- Keep replies short (4-8 sentences max).
"""
EOF

# 4. Build minimal image (fast, small)
podman build -t ollama-tutor-pi -f DockerfileBase .

# 5. (Re)start container
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

echo "Waiting for Ollama server to start (20-40 seconds)..."
sleep 30

# 6. Pull model at runtime (only once; survives restarts via volume)
echo "Pulling llama3.2:3b-instruct (2-5 min depending on network)..."
podman exec ollama-tutor ollama pull llama3.2:3b-instruct

# 7. Create custom tutor model
podman cp ~/ollama/config/Modelfile-kid-tutor ollama-tutor:/tmp/Modelfile-kid-tutor
podman exec ollama-tutor ollama create kid-tutor -f /tmp/Modelfile-kid-tutor

echo ""
echo "Setup finished!"
echo ""
echo "Interactive chat:"
echo "  podman exec -it ollama-tutor ollama run kid-tutor"
echo ""
echo "Quick API test:"
echo "  curl http://127.0.0.1:11434/api/chat -d '{\"model\":\"kid-tutor\",\"messages\":[{\"role\":\"user\",\"content\":\"Why does a ball fall down when I drop it?\"}],\"stream\":false}' | jq -r '.message.content'"
echo ""

# Optional: 3 test prompts
for prompt in \
    "How do I add 1/4 and 1/2?" \
    "Solve this: 3x + 7 = 19" \
    "I don't understand why we multiply when finding area. I'm stupid."
do
    echo "Test: $prompt"
    echo "----------------------------------------"
    curl -s http://127.0.0.1:11434/api/chat -d "{\"model\":\"kid-tutor\",\"messages\":[{\"role\":\"user\",\"content\":\"$prompt\"}],\"stream\":false}" | jq -r '.message.content // "Error"'
    echo "----------------------------------------"
    echo ""
done
