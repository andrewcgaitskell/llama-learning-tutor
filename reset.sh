podman stop ollama-tutor
podman rm ollama-tutor
rm -rf ~/ollama/models/*   # <-- this clears partial blobs/manifests
# Then restart container (use your original run command or script)
podman run -d \
  --name ollama-tutor \
  -v ~/ollama/models:/root/.ollama \
  -p 127.0.0.1:11434:11434 \
  --restart unless-stopped \
  --read-only \
  --tmpfs /tmp:size=256m \
  ollama-tutor-pi   # or whatever your image name is

sleep 30
