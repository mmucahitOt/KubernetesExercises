FROM alpine:3.20

# Install dependencies
RUN apk add --no-cache \
  bash \
  postgresql16-client \
  python3 \
  py3-pip \
  ca-certificates \
  curl \
  unzip && \
  update-ca-certificates

# Install Google Cloud SDK non-interactively
ENV CLOUDSDK_INSTALL_DIR=/opt
ENV CLOUDSDK_CORE_DISABLE_USAGE_REPORTING=true
RUN curl https://sdk.cloud.google.com | CLOUDSDK_CORE_DISABLE_USAGE_REPORTING=true bash -s -- --disable-prompts && \
  mv /opt/google-cloud-sdk /usr/local && \
  ln -s /usr/local/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud && \
  ln -s /usr/local/google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil && \
  rm -rf /var/cache/apk/* /tmp/*

# Add gcloud to PATH
ENV PATH="/usr/local/google-cloud-sdk/bin:${PATH}"

WORKDIR /app

# Copy the script and make it executable
COPY backup_db.sh /usr/local/bin/backup_db.sh
RUN chmod +x /usr/local/bin/backup_db.sh

# Run the script by default
ENTRYPOINT ["/usr/local/bin/backup_db.sh"]
