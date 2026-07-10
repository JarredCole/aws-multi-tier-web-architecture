terraform {
  backend "s3" {
    bucket         = "aws-cicd-s3-bucket-777" 
    key            = "aws-vpc-asg/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locking"
    encrypt        = true
  }
}