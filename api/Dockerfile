FROM python:3.13-slim AS base

# System setup
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_LINK_MODE=copy

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install uv (Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH=/root/.local/bin:$PATH

WORKDIR /app

# Copy only dependency manifests first for better layer caching
COPY pyproject.toml uv.lock* ./

# Install dependencies into a local venv for runtime
RUN uv sync --frozen --no-dev \
    && echo "Dependencies installed"

# Make the venv available on PATH
ENV PATH=/app/.venv/bin:$PATH

# Copy application code
COPY . .

# Expose API port
EXPOSE 8443

# Run via uvicorn directly so we bind 0.0.0.0 inside container
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8443"]


