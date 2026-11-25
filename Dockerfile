FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .

# Instala dependencias y después elimina las herramientas de empaquetado
# (pip, setuptools, wheel y ensurepip): la imagen de ejecución no las
# necesita y así se reduce la superficie de ataque.
RUN pip install --no-cache-dir -r requirements.txt \
    && pip uninstall -y pip setuptools wheel \
    && rm -rf /usr/local/lib/python3.11/ensurepip

# Ejecuta como usuario sin privilegios.
RUN useradd --create-home --shell /usr/sbin/nologin appuser

COPY --chown=appuser:appuser src/ ./src/

USER appuser
ENV PYTHONUNBUFFERED=1
CMD ["python", "src/app.py"]
