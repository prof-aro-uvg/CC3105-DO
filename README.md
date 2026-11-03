# CC3105-DO — DigitalOcean droplets with Terraform + cloud-init

Infrastructure as code for the CC3105 MLOps course lab environment. Terraform creates a group of Ubuntu 22.04 droplets on DigitalOcean, and each droplet configures itself on first boot with **cloud-init**. That replaces the Ansible playbooks and the `basic_config.sh` script used before.

After a single `terraform apply`, every droplet has:

- two course users, `mlops` and `cc3105` (SSH key login only), in a shared `uvg` group
- a shared project directory, `/srv/projects/pf`
- Apache 2 with `mod_rewrite`
- Docker Engine and Docker Compose v2, with passwordless `sudo` for both users on `docker` / `docker-compose`
- a default `ubuntu` image pulled and a `docker1` container created
- the `America/Guatemala` timezone and a daily 19:00 shutdown timer

Terraform also writes an Ansible inventory with the new IPs, so playbooks can still be run against the droplets.

---

## Table of contents

- [How it works](#how-it-works)
- [Repository layout](#repository-layout)
- [What each droplet is configured with](#what-each-droplet-is-configured-with)
- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Configuration](#configuration)
- [Outputs](#outputs)
- [Verifying a droplet](#verifying-a-droplet)
- [Using Ansible afterwards](#using-ansible-afterwards)
- [Branches and environments](#branches-and-environments)
- [Costs and cleanup](#costs-and-cleanup)
- [Migration notes (from the Ansible playbooks)](#migration-notes-from-the-ansible-playbooks)
- [Security notes](#security-notes)
- [Troubleshooting](#troubleshooting)

---

## How it works

```
terraform apply
   │
   ├─ looks up the SSH key "mba" already uploaded to DigitalOcean
   ├─ renders modules/droplets/cloud-init.yaml.tftpl  ──►  user_data
   ├─ creates N droplets: uvg-group-0 … uvg-group-(N-1)
   │       └─ first boot: cloud-init creates users, installs packages,
   │          sets up Docker, timezone and shutdown timer
   └─ writes ansible/inventory.ini from the droplets' public IPs
```

- **Terraform** creates the droplets and owns them for their whole life (create, change, destroy).
- **cloud-init** runs **once**, on each droplet's first boot. Changing the template therefore **replaces** the droplets: `user_data` can't be changed on an existing droplet.
- The DigitalOcean provider is configured only in the root module. The `droplets` module inherits it, so the module can be used with `count` / `for_each` and removed cleanly.

## Repository layout

```
.
├── versions.tf                 # Terraform/provider versions + DigitalOcean provider config
├── variables.tf                # Root variables (do_token)
├── main.tf                     # Calls the droplets module; writes the Ansible inventory
├── outputs.tf                  # IPs and ready-made SSH commands
├── inventory.ini.tftpl         # Template for ansible/inventory.ini
├── terraform.tfvars.example    # Example variables file (copy to terraform.tfvars)
├── .gitignore                  # Keeps state, tfvars and the generated inventory out of git
└── modules/
    └── droplets/
        ├── versions.tf             # Required provider (no provider block here)
        ├── variables.tf            # Module inputs (count, size, region, timezone, …)
        ├── main.tf                 # SSH key lookup + digitalocean_droplet resource
        ├── outputs.tf              # name => IP, name => ID
        └── cloud-init.yaml.tftpl   # First-boot configuration
```

## What each droplet is configured with

| Area | Configuration | Originally from |
|---|---|---|
| Base image | Ubuntu 22.04 (`ubuntu-22-04-x64`), `s-1vcpu-1gb`, region `sfo2`, tags `mlops`, `uvg` | `droplets.tf` |
| Root access | The DigitalOcean SSH key `mba` is installed for `root` | `droplets.tf` |
| Timezone | `America/Guatemala` | `set_timezone.yml` |
| Users and groups | Group `uvg`; users `mlops` and `cc3105` (set by `users`), each with `/bin/bash`, password locked, `mba` public key in `authorized_keys`, member of `uvg` | `basic_config.sh`, `docker-install.yml` |
| Shared directory | `/srv/projects/pf`, owner `root:uvg`, mode `2770` (setgid, so new files inherit the `uvg` group) | `basic_config.sh` |
| Web server | `apache2` installed, `mod_rewrite` enabled, service restarted | `docker-install.yml` |
| Base packages | `aptitude`, `apt-transport-https`, `ca-certificates`, `curl`, `gnupg`, `lsb-release`, `software-properties-common`, `python3-pip`, `python3-setuptools`, `python3-docker`, `virtualenv` | `playbook-docker.yml`, `playbook-docker-compose.yml` |
| Docker | Official Docker apt repository for the droplet's Ubuntu release; `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin` | `playbook-docker.yml`, `playbook-docker-compose.yml` |
| `docker-compose` command | `/usr/local/bin/docker-compose`, a wrapper that runs `docker compose "$@"` | `playbook-docker-compose.yml` |
| sudo | `/etc/sudoers.d/uvg_docker`: one line per user, e.g. `cc3105 ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/local/bin/docker-compose` | `playbook-docker-compose.yml` |
| Default containers | `docker pull ubuntu`, then `docker create --name docker1 ubuntu sleep 1` (created, not started) | `playbook-docker.yml` |
| Daily shutdown | `shutdown-at-19.service` + `shutdown-at-19.timer`, run every day at 19:00 local time | `shutdown_timer.yml` |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) **≥ 1.3**
- A DigitalOcean account and a **personal access token** with write scope
- An SSH key uploaded to DigitalOcean under the name **`mba`** (or set `ssh_key_name`), with the matching private key on your machine

## Quick start

```bash
git clone https://github.com/prof-aro-uvg/CC3105-DO.git
cd CC3105-DO

# Option A: environment variable (recommended)
export DIGITALOCEAN_TOKEN=dop_v1_xxxxxxxxxxxxxxxx

# Option B: tfvars file (git-ignored)
cp terraform.tfvars.example terraform.tfvars   # then edit do_token

terraform init
terraform validate
terraform plan
terraform apply
```

The droplets are up after about a minute. cloud-init needs a few more minutes to install everything (see [Verifying a droplet](#verifying-a-droplet)).

## Configuration

### Root module (`main.tf`)

| Setting | Current value | Meaning |
|---|---|---|
| `droplet_count` | `7` | Number of droplets (minimum 2) |
| `group_name` | `"uvg-group"` | Name prefix: `uvg-group-0`, `uvg-group-1`, … |
| `ssh_key_name` | `"mba"` | Name of the SSH key in DigitalOcean |

Root variable:

| Variable | Type | Default | Description |
|---|---|---|---|
| `do_token` | `string` (sensitive) | `null` | DigitalOcean token. If unset, the provider reads `DIGITALOCEAN_TOKEN`. |

### `modules/droplets` inputs

| Variable | Type | Default | Description |
|---|---|---|---|
| `droplet_count` | `number` | — (required) | Number of droplets; validated `>= 2` |
| `group_name` | `string` | — (required) | Droplet name prefix |
| `ssh_key_name` | `string` | `"mba"` | DigitalOcean SSH key used for `root` and every user in `users` |
| `users` | `list(string)` | `["mlops", "cc3105"]` | Users created on every droplet, all with the same permissions (`uvg` member, SSH key login, passwordless `sudo` for docker/docker-compose) |
| `region` | `string` | `"sfo2"` | Region slug |
| `size` | `string` | `"s-1vcpu-1gb"` | Size slug |
| `image` | `string` | `"ubuntu-22-04-x64"` | Image slug |
| `tags` | `list(string)` | `["mlops", "uvg"]` | Droplet tags |
| `timezone` | `string` | `"America/Guatemala"` | System timezone |
| `shutdown_time` | `string` | `"19:00"` | Daily shutdown time (`HH:MM`, 24 h). `null` disables the timer |
| `container_count` | `number` | `1` | How many default containers to create |
| `container_name` | `string` | `"docker"` | Container name prefix (`docker1`, `docker2`, …) |
| `container_image` | `string` | `"ubuntu"` | Image for the default containers |
| `container_command` | `string` | `"sleep 1"` | Command for the default containers |

Example: three bigger droplets in `sfo3`, without the shutdown timer and with an extra user:

```hcl
module "groups" {
  source = "./modules/droplets"

  droplet_count = 3
  group_name    = "uvg-group"
  ssh_key_name  = "mba"

  region        = "sfo3"
  size          = "s-2vcpu-2gb"
  shutdown_time = null
  users         = ["mlops", "cc3105", "student1"]
}
```

## Outputs

| Output | Example |
|---|---|
| `droplet_ip_addresses` | `{ "uvg-group-0" = "157.230.138.61", … }` |
| `ssh_commands` | `{ "uvg-group-0" = "ssh mlops@157.230.138.61", … }` |

```bash
terraform output droplet_ip_addresses
terraform output -json ssh_commands
```

## Verifying a droplet

```bash
ssh root@<ip>

cloud-init status --wait                  # blocks until first-boot setup finishes
tail -n 50 /var/log/cloud-init-output.log # full log of the setup

timedatectl | grep "Time zone"            # America/Guatemala
id mlops; id cc3105                       # ... groups=...(uvg)
ls -ld /srv/projects/pf                   # drwxrws--- root uvg
apache2ctl -M | grep rewrite              # rewrite_module (shared)
docker --version && docker compose version
docker ps -a                              # docker1 (Created)
systemctl list-timers shutdown-at-19.timer
```

As `mlops` or `cc3105`:

```bash
ssh cc3105@<ip>
sudo docker ps -a            # no password prompt
sudo docker-compose version  # wrapper around "docker compose"
```

## Using Ansible afterwards

`terraform apply` writes `ansible/inventory.ini`. The file is git-ignored because the IPs change every time the droplets are recreated:

```ini
[digitalocean]
157.230.138.61 ansible_user=root # uvg-group-0
165.227.55.143 ansible_user=root # uvg-group-1
...

[servers:children]
digitalocean

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

```bash
ansible -i ansible/inventory.ini all -m ping
ansible-playbook -i ansible/inventory.ini my-playbook.yml
```

## Branches and environments

| Branch | Purpose |
|---|---|
| `main` | Default branch. Reviewed, stable code. |
| `dev` | **Development environment.** Changes are tried here first and applied to a test/dev set of droplets. |
| `prod` | **Production environment.** Matches what is deployed for the course. Only receives changes that worked in `dev`. |

Suggested workflow:

```
feature/<name>  ──PR──►  dev  ──PR──►  prod
                                         │
                       main  ◄──PR───────┘  (keep main in sync with prod)
```

1. Create a branch from `dev`: `git switch dev && git switch -c feature/my-change`.
2. Open a PR into `dev`, then `terraform plan` / `apply` from `dev` to test.
3. When it works, open a PR from `dev` into `prod` and apply from `prod`.

> **Keep dev and prod apart.** Terraform state is local (`terraform.tfstate`, git-ignored), so use a separate working copy per branch: `git worktree add ../CC3105-DO-prod prod`. Also give each environment its own droplet name prefix (for example `group_name = "uvg-dev"` on `dev`). Otherwise both environments create droplets with the same names, and DigitalOcean allows duplicate names, so they are easy to mix up.

## Costs and cleanup

- Each `s-1vcpu-1gb` droplet costs about **US$6/month**. With 7 droplets that's about **US$42/month**.
- **The 19:00 shutdown does not reduce cost.** DigitalOcean bills powered-off droplets at the same rate as running ones. Only destroying them stops billing.
- After a shutdown, power droplets back on from the DigitalOcean console or with `doctl compute droplet-action power-on <id>`.
- When you're done:

```bash
terraform destroy
```

## Migration notes (from the Ansible playbooks)

The playbooks were translated into cloud-init. These problems in the originals were fixed along the way:

| Original problem | Fix |
|---|---|
| `playbook-docker-compose.yml` added the Docker repository but never installed `docker-ce` | Docker Engine is installed |
| The Docker repository was hardcoded to `focal` (20.04) while the droplets run 22.04 | The release codename is detected on the droplet |
| `playbook-docker.yml` nested the package list under a second `name:` key, so the task failed | Packages listed correctly |
| `docker-install.yml` handler: `name`/`state` not indented under `service:` | Apache is restarted explicitly after `a2enmod rewrite` |
| Docker Compose v1.29.2 standalone binary (no longer supported) | Compose v2 plugin + `docker-compose` wrapper, so existing commands and the sudo rule keep working |
| `Persistent=true` on the shutdown timer would shut the droplet down right after it was powered on the next day | `Persistent` removed |
| `basic_config.sh` set the `mlops` password interactively (`passwd`) | Users log in with SSH keys only; passwords are locked |
| Legacy provider block inside the child module | Provider configured in the root module |
| `droplet_count >= 2` precondition was skipped when `droplet_count = 0` | Replaced by a variable `validation` block |

Not carried over:
- `requirements.yml` (`digitalocean.cloud` collection) isn't needed, because Terraform generates the inventory.
- The test host `159.65.99.84` (`test_inventory.ini`) isn't managed by this repository.

## Security notes

- **Never commit** `terraform.tfvars`, `*.tfstate` or tokens. `.gitignore` already excludes them, and this repository is public.
- `mlops` and `cc3105` can run `docker` as root without a password. Docker access is effectively root access, so only give the `mba` key to people who should have that.
- `root` SSH login stays enabled because the inventory uses `ansible_user=root`. Consider disabling it once Ansible is no longer used.
- No DigitalOcean firewall is defined. Apache (80) and SSH (22) are reachable from anywhere.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Error: Unable to authenticate you` | `DIGITALOCEAN_TOKEN` is not set or the token lacks write scope |
| `ssh key "mba" not found` | Upload the key to DigitalOcean or set `ssh_key_name` |
| `docker: command not found` right after creation | cloud-init is still running: `cloud-init status --wait` |
| Setup failed partway | Check `/var/log/cloud-init-output.log`; fix the template and run `terraform apply -replace='module.groups.digitalocean_droplet.droplets[0]'` |
| Changing the template recreates all droplets | Expected: `user_data` only runs on first boot, so Terraform replaces the droplets |
| Droplet is off every evening | That's the 19:00 timer; set `shutdown_time = null` to disable it |
