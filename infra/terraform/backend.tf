terraform {
  backend "s3" {
    bucket         = "devsecops-tf-state-backend-072329308666"
    key            = "platform/devsecops-eks.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "devsecops-tf-locks"
    encrypt        = true
  }
}
