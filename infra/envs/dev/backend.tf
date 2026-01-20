terraform {
  backend "s3" {
    bucket         = "tfstate-saito-lab-202601"
    key            = "saito-infra-lab/dev/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "tf-lock-saito-lab-202601"
    encrypt        = true
  }
}
