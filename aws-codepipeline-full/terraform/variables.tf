variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Used as a prefix on resource names and as the Project tag."
  type        = string
  default     = "cicd-evo"
}

variable "instance_type" {
  description = "EC2 instance type for both staging and prod fleets."
  type        = string
  default     = "t3.micro"
}

variable "branch_name" {
  description = "Git branch CodePipeline tracks."
  type        = string
  default     = "main"
}

variable "github_repo" {
  description = "GitHub repo in 'owner/name' form (must already exist)."
  type        = string
  default     = "eveningcafe/cicd-evo"
}

variable "vpc_id" {
  description = "Existing VPC ID where SGs/EC2/ALB will be placed."
  type        = string
}

variable "subnet_ids" {
  description = "Public subnet IDs (≥2 AZs) for the ALB + EC2 fleets. Must route 0.0.0.0/0 to IGW."
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Provide at least 2 subnet IDs in different AZs."
  }
}

variable "codebuild_subnet_ids" {
  description = "Private subnet IDs (with NAT egress) for the integration-test CodeBuild ENI. The ENI gets no public IP, so the subnet's route table must point 0.0.0.0/0 at a NAT GW (not an IGW). If empty, falls back to subnet_ids — which only works when those happen to have NAT routes."
  type        = list(string)
  default     = []
}

locals {
  effective_codebuild_subnet_ids = length(var.codebuild_subnet_ids) > 0 ? var.codebuild_subnet_ids : var.subnet_ids
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}
