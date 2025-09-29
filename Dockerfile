# Use a lightweight Linux base image
FROM python:3.9-slim

# Install system dependencies for video/audio
RUN apt-get update && apt-get install -y \
    vlc \
    alsa-utils \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy application files
COPY iptv_smart_player.py .
COPY working_streams.json .
COPY config.json .

# Set environment for development
ENV IPTV_ENV=development
ENV DISPLAY=:99

# Start virtual display and run app
CMD ["sh", "-c", "Xvfb :99 -screen 0 1024x768x24 & python3 iptv_smart_player.py"]