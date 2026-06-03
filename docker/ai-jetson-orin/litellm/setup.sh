# With --network host, the container sees host's localhost directly.
docker run -d \
  --name litellm-proxy \
  --network host \
  --env-file "$(pwd)/.env" \
  -e OLLAMA_BASE_URL=http://localhost:11434 \
  -v "$(pwd)/config.yaml":/app/config.yaml \
  ghcr.io/berriai/litellm:main-latest \
  --config /app/config.yaml
