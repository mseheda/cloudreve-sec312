# Region and Availability Zone (AZ)
variable "region" {
  type = string
  default = "ca-central-1"
}

variable "az1" {
  type = string
  default = "ca-central-1a"
}

variable "az2" {
  type = string
  default = "ca-central-1b"
}

# Database
variable "db-name" {
  type = string
  default = "backDb"
}

variable "db-username" {
  type = string
  default = "uname"
}

variable "db-password" {
  type = string
  default = "unamespassword"
}

variable "keypair" {
  type = string
}

# Tags
variable "tags" {
  type = map(string)
  default = {
    Name = "cloudreve"
  }
}

variable "name_prefix" {
  type        = string
  description = "Prefix for naming AWS resources (tags/identifiers)"
  default     = "cloudreve"
}