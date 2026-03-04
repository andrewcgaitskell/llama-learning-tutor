# Official Ollama image – multi-arch support for ARM64 (Raspberry Pi 5)
FROM docker.io/ollama/ollama:latest

# Expose Ollama API (only localhost binding later)
EXPOSE 11434

# Pre-pull the instruct model during build
# This makes the image ~2–3 GB larger but ensures it's ready offline
RUN ollama serve & \
    sleep 10 && \
    ollama pull llama3.2:3b-instruct && \
    pkill ollama

# Default: start the Ollama server
CMD ["serve"]
