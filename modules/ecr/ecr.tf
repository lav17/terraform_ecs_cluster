resource "aws_ecr_repository" "my_ecr_repo" {
  name         = var.ecr_repo_name
  force_delete = true
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "null_resource" "docker_packaging" {
  provisioner "local-exec" {
    working_dir = "./App"
    command     = "update-ecr.bat"
  }


  depends_on = [aws_ecr_repository.my_ecr_repo]

  triggers = {
    "run_at" = timestamp()
  }
}
