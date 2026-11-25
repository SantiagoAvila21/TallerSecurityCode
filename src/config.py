"""Configuración de la aplicación.

Los secretos se leen exclusivamente de variables de entorno y nunca se
versionan en el repositorio.
"""

import os

# Sin valor por defecto: si la variable no existe, la aplicación lo informa
# en lugar de arrancar con un token embebido en el código.
APP_API_TOKEN = os.getenv("APP_API_TOKEN")
