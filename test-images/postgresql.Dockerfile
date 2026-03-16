# @req SCI-ANS-001
# Minimal mock PostgreSQL image compatible with Bitnami chart structure
FROM postgres:16-alpine

# Create user with uid 1001 to match Bitnami chart's runAsUser
RUN addgroup -g 1001 bitnami && \
    adduser -D -u 1001 -G bitnami bitnami

# Create Bitnami-compatible directory structure with proper ownership
RUN mkdir -p /bitnami/postgresql/data /bitnami/postgresql/conf && \
    chown -R 1001:1001 /bitnami && \
    chmod -R 755 /bitnami

# Set environment variables that Bitnami chart expects
ENV PGDATA=/bitnami/postgresql/data \
    POSTGRESQL_VOLUME_DIR=/bitnami/postgresql \
    POSTGRESQL_DATA_DIR=/bitnami/postgresql/data

# Run as bitnami user (uid 1001) to match chart's securityContext
USER 1001

EXPOSE 5432

# Use default postgres entrypoint
CMD ["postgres"]