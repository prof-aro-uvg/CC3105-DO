# terraform-digitalocean-droplets

Terraform that deploys a group of Ubuntu 22.04 droplets on DigitalOcean and configures them on first boot with cloud-init (replacing the earlier Ansible playbooks):

- `mlops` user (SSH key only) in group `uvg`, shared `/srv/projects/pf` directory (`root:uvg`, `2770`)
- apache2 with `mod_rewrite`
- Docker Engine + Compose v2 (`docker-compose` wrapper kept), passwordless sudo for `mlops` on docker/docker-compose
- Default `ubuntu` image pulled and `docker1` container created
- Timezone `America/Guatemala` and a daily 19:00 shutdown timer
- Generated Ansible inventory at `ansible/inventory.ini`

## Usage

```bash
export DIGITALOCEAN_TOKEN=dop_v1_...
terraform init
terraform apply
```

Watch first-boot progress on a droplet with `cloud-init status --wait` or `/var/log/cloud-init-output.log`.

Note: powered-off droplets are still billed; run `terraform destroy` when done.
