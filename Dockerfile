FROM python:3.12-slim

LABEL org.opencontainers.image.source="https://github.com/Walaskien/gitlab-ci-pipeline"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /srv

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/server.py .

# After the dependency layer, so a new commit does not re-run pip.
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}

RUN useradd --system --uid 10001 --no-create-home app
USER 10001

EXPOSE 8000

# The slim image has no curl, python is already there.
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=5 \
    CMD ["python", "-c", "import urllib.request as u; u.urlopen('http://127.0.0.1:8000/health', timeout=2)"]

# One worker on purpose: counters and the notes list live in process memory,
# so a second worker would show a different half of the data on every request.
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "1", "--threads", "4", \
     "--worker-tmp-dir", "/dev/shm", "--access-logfile", "-", "server:create_app()"]
