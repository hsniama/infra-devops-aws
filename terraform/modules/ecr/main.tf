resource "aws_ecr_repository" "this" {
  name                 = var.repo_name
  image_tag_mutability = "MUTABLE" //Define si las etiquetas de las imágenes (tags) pueden ser sobrescritas: "MUTABLE" → puedes volver a subir una imagen con el mismo tag y reemplazarla. "IMMUTABLE" → una vez que subes una imagen con un tag, no se puede sobrescribir (más seguro en producción).

  image_scanning_configuration { // Activa el escaneo automático de vulnerabilidades cada vez que se sube una imagen al repositorio.
    scan_on_push = true          // AWS ECR usa Amazon Inspector para revisar CVEs y problemas de seguridad.
  }

  tags = {
    Name = "${var.name_prefix}-${var.repo_name}"
  }
}
