terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

#module "state_module" {
#  source         = "./modules/state-files"
#  bucket_name    = local.bucket_name
#  dynamoDB_table = local.dynamoDB_table
#}

module "ecr_module" {
  source        = "./modules/ecr"
  ecr_repo_name = local.ecr_repo_name

}

module "ecs-cluster" {
  source                = "./modules/ecs"
  demo_app_cluster_name = local.demo_app_cluster_name
  ecr_repo_url          = module.ecr_module.repo_url
  TF_VAR_CLOUDFRONT_IP  = var.TF_VAR_CLOUDFRONT_IP
}
