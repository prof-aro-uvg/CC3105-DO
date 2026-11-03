module "groups" {
  source = "./modules/droplets"

  droplet_count = 7
  group_name    = "uvg-group"
  ssh_key_name  = "mba"
}

# Ansible inventory generated from the droplets Terraform created,
# replacing the hand-maintained inventory.ini.
resource "local_file" "ansible_inventory" {
  filename        = "${path.root}/ansible/inventory.ini"
  file_permission = "0644"
  content = templatefile("${path.root}/inventory.ini.tftpl", {
    droplets = module.groups.droplet_ip_addresses
  })
}
