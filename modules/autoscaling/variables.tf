variable "namespace" {
  type = string
}

variable "ssh_keypair" {
  type = string
}

variable "vpc" {
  type = any
}

variable "sg" {
  type = any
}

variable "create_autoscaling_service_linked_role" {
  description = "Tạo service-linked role AWSServiceRoleForAutoScaling. Đặt true trên account mới chưa có role; để false nếu role đã tồn tại (role là singleton của account, không thể tạo 2 lần)."
  type        = bool
  default     = false
}

variable "db_config" {
  type = object({
    user     = string
    password = string
    database = string
    hostname = string
    port     = string
  })
}