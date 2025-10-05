FROM postgres:16-alpine

# Environment variables may be overridden at runtime
ENV POSTGRES_DB=todo_db \
  POSTGRES_USER=todo_user \
  POSTGRES_PASSWORD=todo_password

# Copy initialization scripts. Any .sql or .sh here runs on first container start
COPY initdb/ /docker-entrypoint-initdb.d/

# Expose PostgreSQL port
EXPOSE 5432

# Use upstream entrypoint and default command
HEALTHCHECK --interval=10s --timeout=3s --retries=10 CMD pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" || exit 1

