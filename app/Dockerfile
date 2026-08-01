# === Builder ===
FROM python:3.12-slim-bookworm AS builder

# Set working directory
WORKDIR /usr/src/app

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libc6-dev make git \
    libffi-dev libssl-dev python3-dev \
    libxml2-dev libxslt-dev \
    libjpeg62-turbo-dev zlib1g-dev libfreetype6-dev

# Upgrade pip and build dependencies
RUN pip install --upgrade pip "setuptools>=78.1.1" "wheel>=0.46.2" "jaraco.context>=6.1.0"

# Install project requirements
COPY requirements.txt .
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels -r requirements.txt

# === Runner ===
FROM python:3.12-slim-bookworm AS runner

# Create the app user and group
RUN addgroup --system app && adduser --system --group app

# Create directories for the app
RUN mkdir -p /home/app/web/staticfiles && \
    mkdir -p /home/app/web/mediafiles && \
    chown -R app:app /home/app

# Use /home/app as the working directory
WORKDIR /home/app

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 libncurses5 libfreetype6 netcat-openbsd

# Clean up the apt cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy project requirements
COPY --from=builder /usr/src/app/wheels /wheels
COPY --from=builder /usr/src/app/requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir --upgrade pip "setuptools>=78.1.1" "wheel>=0.46.2" "jaraco.context>=6.1.0" && pip install --no-cache /wheels/*

# Copy the entrypoint.sh script (if you have one)
COPY --chown=app:app ./entrypoint.sh /home/app/web
RUN chmod +x /home/app/web/entrypoint.sh

# Copy the Django app
COPY --chown=app:app . /home/app/web

# Set the working directory to the Django app
WORKDIR /home/app/web

# Change to non-root user
USER app

# Expose the port
EXPOSE 8000

# Start the app
ENTRYPOINT ["/home/app/web/entrypoint.sh"]