# Use a minimal Linux base image
FROM alpine:3

ARG TARGETARCH
ARG BINARY

# Install certificates for secure external connections (like Pushover/HTTPS) and timezones
RUN apk update && \
    apk upgrade && \
    apk add \
        ca-certificates \
        tzdata \
        libc6-compat && \
    apk cache purge

# Create the default data directory so we can map it safely
RUN mkdir -p /app/data

# Set the working directory inside the container
WORKDIR /app
ADD "${BINARY}" /app/goihcapp

ENTRYPOINT [ "/app/goihcapp" ]

# Expose HTTP and HTTPS ports
EXPOSE 80
EXPOSE 443
