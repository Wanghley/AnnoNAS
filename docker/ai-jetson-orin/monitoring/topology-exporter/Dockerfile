FROM python:3.11-slim
ENV PYTHONUNBUFFERED=1
RUN apt-get update && apt-get install -y openssh-client && rm -rf /var/lib/apt/lists/*
RUN pip install prometheus-client pyyaml
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh
COPY id_ed25519 /root/.ssh/annogrid_topology
RUN chmod 600 /root/.ssh/annogrid_topology
COPY exporter.py /exporter.py
CMD ["python", "/exporter.py"]
