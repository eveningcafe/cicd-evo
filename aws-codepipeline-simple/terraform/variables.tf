variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "project_name" {
  type    = string
  default = "cicd-evo-simple"
}

variable "subnet_id" {
  description = "A PUBLIC subnet (route table → IGW). The single EC2 lives here."
  type        = string
}

variable "vpc_id" {
  description = "The VPC the subnet belongs to."
  type        = string
}

variable "github_repo" {
  type    = string
  default = "eveningcafe/cicd-evo"
}

variable "branch_name" {
  type    = string
  default = "main"
}
