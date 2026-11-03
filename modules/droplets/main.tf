data "digitalocean_ssh_key" "default" {
  name = var.ssh_key_name
}

resource "digitalocean_droplet" "droplets" {
  count = var.droplet_count

  name     = "${var.group_name}-${count.index}"
  image    = var.image
  region   = var.region
  size     = var.size
  tags     = var.tags
  ssh_keys = [data.digitalocean_ssh_key.default.fingerprint]

  # Replaces basic_config.sh and the Ansible playbooks (docker-install.yml,
  # playbook-docker.yml, playbook-docker-compose.yml, set_timezone.yml,
  # shutdown_timer.yml): runs once on first boot.
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    ssh_public_key    = data.digitalocean_ssh_key.default.public_key
    users             = var.users
    timezone          = var.timezone
    shutdown_time     = var.shutdown_time
    container_count   = var.container_count
    container_name    = var.container_name
    container_image   = var.container_image
    container_command = var.container_command
  })
}
