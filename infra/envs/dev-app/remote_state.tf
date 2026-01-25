data "terraform_remote_state" "core" {
  backend = "s3"
  config = {
    bucket         = "tfstate-saito-lab-202601"
    key            = "saito-infra-lab/dev-core/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "tf-lock-saito-lab-202601"
    encrypt        = true
  }
}
