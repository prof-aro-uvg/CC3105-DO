variable "droplet_count" {
  description = "Number of droplets to create"
  type        = number

  validation {
    condition     = var.droplet_count >= 2
    error_message = "At least two droplets must be created."
  }
}

variable "group_name" {
  description = "Prefix for droplet names (<group_name>-<index>)"
  type        = string
}

variable "ssh_key_name" {
  description = "Name of the SSH key already uploaded to DigitalOcean"
  type        = string
  default     = "mba"
}

variable "region" {
  description = "DigitalOcean region slug"
  type        = string
  default     = "sfo2"
}

variable "size" {
  description = "Droplet size slug"
  type        = string
  default     = "s-1vcpu-1gb"
}

variable "image" {
  description = "Droplet image slug"
  type        = string
  default     = "ubuntu-22-04-x64"
}

variable "tags" {
  description = "Tags applied to every droplet"
  type        = list(string)
  default     = ["mlops", "uvg"]
}

# --- set_timezone.yml / shutdown_timer.yml ---
variable "timezone" {
  description = "System timezone"
  type        = string
  default     = "America/Guatemala"
}

variable "shutdown_time" {
  description = "Daily shutdown time (HH:MM, in var.timezone). null disables the timer."
  type        = string
  default     = "19:00"

  validation {
    condition     = var.shutdown_time == null || can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.shutdown_time))
    error_message = "shutdown_time must be HH:MM (24h) or null."
  }
}

# --- playbook-docker.yml ---
variable "container_count" {
  description = "Number of default containers to create"
  type        = number
  default     = 1
}

variable "container_name" {
  description = "Default container name prefix (a 1-based index is appended)"
  type        = string
  default     = "docker"
}

variable "container_image" {
  description = "Default container image"
  type        = string
  default     = "ubuntu"
}

variable "container_command" {
  description = "Default container command"
  type        = string
  default     = "sleep 1"
}
