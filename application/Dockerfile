# syntax=docker/dockerfile:1.7
FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY src/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY src/ /app/

ARG APP_VERSION=0.0.0
ENV APP_VERSION=${APP_VERSION}

EXPOSE 8080
USER 1000:1000

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]
