terraform {
  backend "s3" {
    bucket         = "devsecops-tf-state-backend"
    key            = "platform/devsecops-eks.tfstate"
    region         = "us-east-1"
    dynamodb_table = "devsecops-tf-locks"
    encrypt        = true
  }
}
