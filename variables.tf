variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Name prefix for project resources"
  type        = string
  default     = "flagship"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "container_image_digest" {
  description = "ECR image digest to deploy (pinned for reproducibility instead of :latest)"
  type        = string
  default     = "sha256:5d648407b81c4f382e0a5f6cda6679a9c38c04a28474f2d7ef5e2aa54c4b45f9"
}
