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

# === Pause so the window doesn't close immediately ===
read -p "Press Enter to close this window..." dummy
# Alternative (no input needed): sleep 60
