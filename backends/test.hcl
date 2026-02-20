bucket         = "tfstate-devops-henry-1720" // Escribe el nombre del bucket de S3 donde se almacenará el estado de Terraform
key            = "test/infra.tfstate" // Escribe la ruta y el nombre del archivo de estado de Terraform dentro del bucket de S3 (puedes cambiar "test/infra.tfstate" por la ruta y el nombre que prefieras)
region         = "us-east-1" // Escribe la región de AWS donde se encuentra el bucket de S3 y la tabla de DynamoDB
dynamodb_table = "tfstate-locks-devops" // Escribe el nombre de la tabla de DynamoDB que se utilizará para el bloqueo del estado de Terraform
encrypt        = true
