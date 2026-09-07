variable "project_id" {
  type = string
}

variable "location" {
  type = string
}

variable "repository_id" {
  type = string
}

variable "description" {
  type    = string
  default = "Docker images"
}

variable "keep_count" {
  description = "Number of most recent image versions to keep"
  type        = number
  default     = 10
}

variable "delete_older_than" {
  description = "Duration string for DELETE cleanup (e.g. 2592000s = 30 days)"
  type        = string
  default     = "2592000s"
}
