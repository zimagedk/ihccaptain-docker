# Use a minimal Linux base image
FROM alpine:3

# Install certificates for secure external connections (like Pushover/HTTPS) and timezones
RUN apk --no-cache upgrade && \
    apk --no-cache add \
        ca-certificates \
        tzdata \
        libc6-compat

# Create the default data directory so we can map it safely
RUN mkdir -p /app/data

# Set the working directory inside the container
WORKDIR /app
ADD goihccap /app

ENTRYPOINT [ "/app/goihccap" ]

# Expose HTTP and HTTPS ports
EXPOSE 80
EXPOSE 443
