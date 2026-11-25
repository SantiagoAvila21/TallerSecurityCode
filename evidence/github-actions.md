# Evidencia GitHub Actions

Repositorio: https://github.com/SantiagoAvila21/TallerSecurityCode
Workflow: `.github/workflows/security.yml` ("Security as Code")
Evento: `push` a `main`

## Ejecución final (exitosa)

- Run: **45649921217**
- URL: https://github.com/SantiagoAvila21/TallerSecurityCode/actions/runs/45649921217
- Commit: `19ced23` (`docs: completa informe y evidencias posteriores`)
- Conclusión: **success**

| Job | Conclusión | Pasos |
|---|---|---|
| Detectar secretos | success | Checkout, Gitleaks |
| Analizar Terraform | success | Checkout, Checkov |
| Analizar imagen | success | Checkout, Construir imagen, Escanear imagen |

## Ejecución previa (fallida y corregida)

- Run: **45649511185**
- URL: https://github.com/SantiagoAvila21/TallerSecurityCode/actions/runs/45649511185
- Conclusión: failure

Motivos:

1. **Analizar imagen** falló en `Set up job` porque
   `aquasecurity/trivy-action@0.28.0` no es un tag válido (los tags llevan
   prefijo `v`). Se corrigió a `v0.36.0`.
2. **Detectar secretos** falló porque el JSON crudo de Trivy incluía la variable
   `GPG_KEY` de la imagen base y Gitleaks la clasificó como `generic-api-key`.
   Se eliminó la configuración de imagen de los reportes de evidencia y se
   verificó de nuevo con gitleaks sobre el historial completo.

Ambos problemas se corrigieron y la ejecución posterior terminó en verde. El
fallo del pipeline fue tratado como parte del diagnóstico, no se desactivó
ningún control.
