FROM python:3.11-slim
RUN apt-get update && apt-get install -y openssh-client && rm -rf /var/lib/apt/lists/*
RUN pip install prometheus-client
COPY exporter.py /exporter.py
CMD ["python", "/exporter.py"]
