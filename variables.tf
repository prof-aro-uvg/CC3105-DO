variable "do_token" {
  description = "DigitalOcean API token (or leave unset and export DIGITALOCEAN_TOKEN)"
  type        = string
  sensitive   = true
  default     = null
}
