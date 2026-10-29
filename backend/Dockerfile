FROM python:3.14-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app
RUN useradd --create-home --uid 10001 ghostwork

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY --chown=ghostwork:ghostwork . .
USER ghostwork

EXPOSE 8000
# Same image runs the API, the Celery worker and Celery beat (see docker-compose.yml).
CMD ["sh", "-c", "python -m alembic upgrade head && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --proxy-headers"]
