variable "aws_region" {
  type        = string
  description = "The AWS Region to deploy infrastructure"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  type        = string
  description = "The main CIDR block for the custom VPC"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for Public Subnet A and B"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for Private Subnet A and B"
}

variable "data_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for Data Subnet A and B"
}