FROM alpine:3.20

# Install only what we need to run the script
RUN apk add --no-cache \
  bash \
  curl \
  postgresql16-client \
  ca-certificates && update-ca-certificates

WORKDIR /app

# Copy the script and make it executable
COPY add_todo.sh /usr/local/bin/add_todo.sh
RUN chmod +x /usr/local/bin/add_todo.sh

# The DB URL is provided at runtime; optional note can be passed as CMD arg

# Run the script by default; pass note text via CMD if desired
ENTRYPOINT ["/usr/local/bin/add_todo.sh"]
CMD []
