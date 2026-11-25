# Infraestructura de ejemplo. No ejecutar terraform apply.
# Configuración endurecida: bucket privado, cifrado en reposo y bloqueo de
# todo acceso público.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_s3_bucket" "lab_data" {
  bucket = "security-as-code-lab-private-example-123456"

  tags = {
    Name        = "security-as-code-lab"
    Environment = "lab"
  }
}

# Propiedad del bucket: deshabilita las ACL (BucketOwnerEnforced), por lo que
# el acceso se gestiona únicamente mediante políticas IAM.
resource "aws_s3_bucket_ownership_controls" "lab_data" {
  bucket = aws_s3_bucket.lab_data.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Bloquea ACL públicas, políticas públicas y acceso público en general.
resource "aws_s3_bucket_public_access_block" "lab_data" {
  bucket = aws_s3_bucket.lab_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Cifrado en reposo con KMS y claves de bucket para reducir costos de KMS.
resource "aws_s3_bucket_server_side_encryption_configuration" "lab_data" {
  bucket = aws_s3_bucket.lab_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Versionado: permite recuperar objetos sobrescritos o eliminados.
resource "aws_s3_bucket_versioning" "lab_data" {
  bucket = aws_s3_bucket.lab_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Ciclo de vida: expira versiones no vigentes para controlar el almacenamiento.
resource "aws_s3_bucket_lifecycle_configuration" "lab_data" {
  bucket = aws_s3_bucket.lab_data.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    # Limpia cargas multipart incompletas para evitar objetos huérfanos.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}
