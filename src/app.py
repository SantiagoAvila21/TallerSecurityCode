"""Aplicación mínima para ilustrar configuración segura por entorno."""

from config import APP_API_TOKEN


def main() -> None:
    if not APP_API_TOKEN:
        print("APP_API_TOKEN no está configurado.")
        return

    # No imprimir el token ni incluirlo en logs.
    print("Aplicación de demostración iniciada.")
    print("Token configurado: sí")


if __name__ == "__main__":
    main()
