# Update system
sudo apt update && sudo apt upgrade -y

# Install Podman (64-bit Raspberry Pi OS Bookworm or later)
sudo apt install podman -y

# Optional: install podman-compose if you like compose-style files later
sudo apt install podman-compose -y

# Verify
podman --version
# Should show podman version 4.x or higher
