FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

ARG REQUIREMENTS_FILE=Docker/requirements.txt
COPY ${REQUIREMENTS_FILE} ./requirements.txt
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY DataWarehouse ./DataWarehouse
COPY app ./app

RUN mkdir -p /app/data/private /app/warehouse

EXPOSE 8000
