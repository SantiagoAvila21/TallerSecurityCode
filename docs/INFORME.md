# Informe individual — Laboratorio Security as Code

## 1. Datos de entrega

- **Nombre:** Santiago Avila
- **Repositorio:** https://github.com/SantiagoAvila21/TallerSecurityCode
- **Rama:** `main`
- **Fecha:** 25 de noviembre de 2026

## 2. Análisis inicial

| Herramienta | Archivo/recurso | Hallazgo / regla / CVE | Severidad | Riesgo | Evidencia |
|---|---|---|---|---|---|
| Gitleaks 8.30.1 | `src/config.py`, línea 5 | `github-pat`: `ghp_` + 36 ceros | Alta (si fuera real) | Token versionado y presente en el historial Git; acceso no autorizado si la credencial fuera válida | `evidence/gitleaks-antes.txt` |
| Checkov 3.4.11 | `infra/main.tf`, `aws_s3_bucket.lab_data` | `CKV_AWS_20`: ACL con lectura pública | Alta | Cualquier usuario de Internet podría leer los objetos del bucket | `evidence/checkov-antes.txt` |
| Checkov 3.4.11 | `infra/main.tf`, `aws_s3_bucket_public_access_block.lab_data` | `CKV_AWS_53`, `CKV_AWS_54`, `CKV_AWS_55`, `CKV_AWS_56`: bloqueo público deshabilitado | Alta | Una política o ACL pública podría volver a exponer el bucket | `evidence/checkov-antes.txt` |
| Checkov 3.4.11 | `infra/main.tf`, `aws_s3_bucket.lab_data` | `CKV_AWS_19`, `CKV_AWS_145`: sin cifrado explícito/KMS | Media | Datos en reposo sin control de cifrado verificable | `evidence/checkov-antes.txt` |
| Checkov 3.4.11 | `infra/main.tf`, `aws_s3_bucket.lab_data` | `CKV_AWS_21`, `CKV2_AWS_61`, `CKV_AWS_300`: sin versionado ni ciclo de vida | Baja/Media | Pérdida de datos ante borrado accidental y objetos huérfanos | `evidence/checkov-antes.txt` |
| Trivy 0.76.2 | `urllib3==1.25.3` | `CVE-2020-7212`, `CVE-2023-43804`, `CVE-2025-66418`, `CVE-2025-66471`, `CVE-2026-21441`, `CVE-2026-44431`, `CVE-2026-97689` | Alta | DoS, filtración de cabeceras en redirecciones y agotamiento de memoria | `evidence/trivy-antes.txt` |
| Trivy 0.76.2 | `wheel 0.45.1` (imagen base) | `CVE-2026-24049` | Alta | Ejecución de código/privilegios elevados al instalar un wheel malicioso | `evidence/trivy-antes.txt` |
| Trivy 0.76.2 | Sistema operativo Debian 13.8 | 54 CVEs HIGH | Alta | Vulnerabilidades de la imagen base; la mayoría sin versión corregida | `evidence/trivy-antes.txt` |

**Nota sobre Gitleaks:** con la configuración oficial, Gitleaks 8.30.1 **no reporta**
el valor del laboratorio porque la regla `github-pat` exige `entropy = 3` y el
valor es `ghp_` seguido de 36 ceros (entropía 0). Es un falso negativo del
escáner, no una ausencia de riesgo. Para documentar el hallazgo se ejecutó la
misma regla sin el filtro de entropía sobre una copia de la configuración
oficial; el resultado fue `src/config.py:5`, regla `github-pat`, también
presente en el commit `74b291a` del historial. Ver `evidence/gitleaks-antes.txt`.

## 3. Correcciones realizadas

### 3.1 Secreto en `src/config.py`

- **Causa:** el token estaba escrito directamente en el código y quedó en el
  historial Git.
- **Cambio:** se eliminó el valor y ahora `APP_API_TOKEN` se lee con
  `os.getenv("APP_API_TOKEN")`, sin valor por defecto. `src/app.py` usa esa
  variable y no imprime el token. `.env` y `.env.*` ya estaban en `.gitignore`
  (se conserva `.env.example` como plantilla).
- **Por qué reduce el riesgo:** el repositorio deja de contener la credencial y
  la aplicación falla de forma segura si el entorno no está configurado.
- **Resultado:** `gitleaks dir .` y `gitleaks git .` no reportan hallazgos. El
  historial anterior conserva el valor ficticio; en un incidente real se debe
  rotar la credencial y limpiar el historial. Ver `evidence/gitleaks-despues.txt`.

### 3.2 Bucket S3 en `infra/main.tf`

- **Causa:** ACL `public-read` y las cuatro opciones de
  `aws_s3_bucket_public_access_block` en `false`.
- **Cambio:** se eliminó la ACL pública, se añadieron
  `aws_s3_bucket_ownership_controls` con `BucketOwnerEnforced`, se activaron
  `block_public_acls`, `block_public_policy`, `ignore_public_acls` y
  `restrict_public_buckets`, y se agregaron cifrado con KMS, versionado y ciclo
  de vida (incluida la limpieza de cargas multipart incompletas).
- **Por qué reduce el riesgo:** impide exponer el bucket mediante ACL o política
  pública, protege los datos en reposo y permite recuperar versiones anteriores.
- **Resultado:** Checkov pasa de 5 controles aprobados y 12 fallidos a
  **14 aprobados y 0 fallidos**. Las excepciones `CKV_AWS_18` (logging),
  `CKV_AWS_144` (replicación cross-region) y `CKV2_AWS_62` (notificaciones)
  están en `.checkov.yaml` con justificación: requieren infraestructura
  adicional (otro bucket, otra región, SNS/SQS) que no aporta valor a un bucket
  de práctica que nunca se despliega. No se desactivó ningún control de acceso
  público, cifrado o versionado.

### 3.3 Dependencias y imagen Docker

- **Causa:** `urllib3==1.25.3` fijaba una versión con CVEs conocidos; la imagen
  además conservaba `pip`, `setuptools`, `wheel` y `ensurepip`, que aportaban
  vulnerabilidades de herramientas de empaquetado.
- **Cambio:** `urllib3==2.8.0`; el Dockerfile instala las dependencias y luego
  elimina `pip`, `setuptools`, `wheel` y `ensurepip` de la imagen final; la
  aplicación se ejecuta con el usuario sin privilegios `appuser`.
- **Por qué reduce el riesgo:** corrige los CVEs de la librería y disminuye la
  superficie de ataque del contenedor (sin gestor de paquetes ni root).
- **Resultado:** las dependencias Python pasan de 9 hallazgos HIGH a **0**.
  Permanecen 54 CVEs HIGH del sistema operativo Debian de la imagen base; la
  mayoría no tiene versión corregida publicada. Se mitigan actualizando
  periódicamente la imagen base y se documentan como riesgo residual. Ver
  `evidence/trivy-despues.txt`.

## 4. Integración continua

El workflow `.github/workflows/security.yml` se dispara en **pull requests hacia
`main`** y en **pushes a `main`**. Tiene tres jobs independientes:

1. **`gitleaks`:** hace checkout con `fetch-depth: 0` (historial completo) y
   ejecuta `gitleaks/gitleaks-action@v2` con el `GITHUB_TOKEN` para detectar
   secretos en los commits del PR o del push.
2. **`checkov`:** analiza únicamente `infra/` con framework Terraform mediante
   `bridgecrewio/checkov-action@v12` y la configuración `.checkov.yaml`.
3. **`trivy`:** construye la imagen con Docker y la escanea con
   `aquasecurity/trivy-action@0.28.0`, severidades HIGH y CRITICAL, solo
   dependencias de aplicación (`vuln-type: library`), ignorando las que no
   tienen corrección (`ignore-unfixed: true`) y con `exit-code: 1`.

**Permisos:** el workflow declara únicamente `contents: read` y
`pull-requests: read`, que es lo mínimo necesario para el checkout y para que
Gitleaks compare los commits del PR. No se concede `write` a ningún job. Además,
`concurrency` cancela ejecuciones antiguas de la misma rama.

**Resultado:** la ejecución final sobre `main` terminó en **success** con los
tres jobs en verde:
<https://github.com/SantiagoAvila21/TallerSecurityCode/actions/runs/45649921217>

**Incidencias encontradas y corregidas en el propio pipeline.** La primera
ejecución falló y sirvió para detectar dos problemas reales:

1. El job de imagen falló en `Set up job` porque el tag
   `aquasecurity/trivy-action@0.28.0` no existe: los tags del repositorio llevan
   prefijo `v`. Se cambió a `v0.36.0`.
2. El job de Gitleaks falló porque el reporte JSON crudo de Trivy incluía la
   variable `GPG_KEY` de la imagen base y Gitleaks la interpretó como
   `generic-api-key`. Se sanitizaron los reportes (se conservan solo los
   resultados de vulnerabilidades, sin la configuración de la imagen) y se
   repitió la ejecución.

Esto ilustra por qué el pipeline debe probarse: un control mal configurado
puede fallar por motivos distintos a una vulnerabilidad real, y un reporte de
evidencia puede introducir hallazgos si no se redacta. Ver
`evidence/github-actions.md`.

## 5. Decisiones del desarrollador

1. **No dejar un valor por defecto para el token.** Podría haberse usado
   `os.getenv("APP_API_TOKEN", "placeholder")`, pero eso mantiene un secreto
   embebido y oculta una configuración incompleta. Preferí que la aplicación
   informe que falta la variable.
2. **Eliminar el gestor de paquetes de la imagen final.** En lugar de solo
   actualizar `urllib3`, quité `pip`, `setuptools`, `wheel` y `ensurepip` del
   runtime y ejecuté como usuario sin privilegios. Es una decisión propia
   orientada a reducir superficie de ataque; el costo es que la imagen ya no
   puede instalar paquetes en caliente, algo que en producción no se desea.
3. **Recomendación que decidí no aplicar:** Checkov sugiere replicación
   cross-region, logging de acceso y notificaciones de eventos. No las
   implementé porque exigen una segunda región, un bucket de logs con su propia
   política y recursos SNS/SQS: aumentarían el costo y la complejidad de un
   laboratorio que nunca se despliega. En lugar de desactivar Checkov, limité la
   excepción a esos tres controles y la justifiqué en `.checkov.yaml`.
4. **No reescribir el historial Git.** El valor es ficticio y la reescritura es
   destructiva; documenté el procedimiento correcto para un incidente real
   (rotar la credencial y limpiar el historial) en lugar de alterar commits.

## 6. Evidencias

- `evidence/gitleaks-antes.txt` y `evidence/gitleaks-despues.txt`
- `evidence/checkov-antes.txt` y `evidence/checkov-despues.txt`
- `evidence/trivy-antes.txt` y `evidence/trivy-despues.txt`
- `evidence/github-actions.md` (resultado de las ejecuciones en Actions)
- `evidence/raw/` (reportes JSON sanitizados y tablas completas de las herramientas)
- Pull request: el repositorio se publicó directamente en `main` por solicitud
  del autor; el workflow también se ejecuta en cada PR hacia `main`.

## 7. Reflexión

1. **¿Qué diferencia hay entre encontrar un problema y prevenir que vuelva a
   introducirse?** Encontrarlo es una acción puntual; prevenirlo requiere un
   control automatizado que se ejecute en cada cambio. Los escáneres locales
   sirven para diagnosticar, pero el workflow en CI es lo que impide que una
   regresión llegue a `main`. Además, una herramienta puede tener falsos
   negativos (como el filtro de entropía de Gitleaks); por eso conviene combinar
   controles y revisar sus limitaciones.
2. **¿Qué riesgos no cubren estos tres escáneres?** No cubren vulnerabilidades
   de lógica de negocio, inyección en tiempo de ejecución, autenticación y
   autorización mal diseñadas, dependencias dinámicas no declaradas, errores de
   configuración de red, exposición de datos en logs ni amenazas internas.
   Tampoco garantizan que las políticas de infraestructura se apliquen en la
   nube real ni analizan el código de la aplicación (SAST/DAST).
3. **¿Por qué no basta con que el pipeline esté en verde?** Porque el pipeline
   solo verifica los controles configurados sobre los archivos y la imagen. Un
   `exit 0` no demuestra que no existan riesgos: puede haber hallazgos no
   cubiertos, excepciones justificadas, CVEs sin corrección o un escáner
   desactualizado. La decisión de aceptar un riesgo residual debe ser explícita
   y documentada.
4. **¿Qué control agregarías a un proyecto real y por qué?** Agregaría un
   análisis SAST (por ejemplo, CodeQL o Semgrep) y un DAST básico, además de
   Dependabot/Renovate para actualizar dependencias y la imagen base de forma
   continua. Los escáneres actuales revisan secretos, IaC y dependencias, pero
   no detectan vulnerabilidades en el código propio ni mantienen las versiones
   al día después del merge.
