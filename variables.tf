variable "namespace" {
  description = "The project namespace to use for unique resource naming"
  default     = "my-cool-project"
  type        = string
}

variable "ssh_keypair" {
  description = "SSH keypair to use for EC2 instance"
  default     = null # Null rất hữu ích cho các biến tùy chọn không có giá trị mặc định cụ thể.
  type        = string
}

variable "region" {
  description = "AWS region"
  default     = "us-east-1"
  type        = string
}

variable "create_autoscaling_service_linked_role" {
  description = "Đặt true trên account AWS mới chưa có AWSServiceRoleForAutoScaling (tránh race khi AWS tự sinh SLR). Để false (mặc định) nếu role đã tồn tại để plan/apply bình thường."
  type        = bool
  default     = false
}