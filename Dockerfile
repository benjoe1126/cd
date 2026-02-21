FROM python:3.13-alpine
WORKDIR application
COPY app/app.py .
COPY pyproject.toml .
RUN pip install uv
RUN uv sync
ENV PYTHONUNBUFFERED=1
ENTRYPOINT ["uv", "run", "app/app.py"]