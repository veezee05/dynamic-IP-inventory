# Automated Deployment of Campus Lost & Found Portal

Automates AWS infrastructure provisioning (Terraform), server configuration and host
discovery (Ansible with dynamic inventory), and application deployment (Docker) for a
Campus Lost & Found web portal.

## Architecture

```
Laptop
  |
  |  terraform apply
  v
AWS EC2 (tagged: Project=lost-and-found, Environment=dev, Role=web)
  ^
  |  live AWS API lookup by tag (no static IP file)
  |
Ansible (amazon.aws.aws_ec2 dynamic inventory)
  |
  |  ansible-playbook deploy.yml
  v
Docker (installs, builds image, runs container on port 80)
  |
  v
Nginx serves index.html --> Browser
```

## Stack

| Tool | Purpose |
|---|---|
| Terraform | Creates the AWS EC2 instance + security group, tags the instance |
| Ansible (dynamic inventory) | Discovers the tagged EC2 instance live from AWS at runtime, installs Docker, deploys the app |
| Docker | Packages and runs the Lost & Found portal via nginx |
| GitHub | Version control (secrets excluded via `.gitignore`) |

## What Makes This Different From a Basic Terraform + Ansible Setup

A common beginner pipeline hardcodes the EC2 IP into a static `inventory.ini` file after
every `terraform apply`, requiring a manual copy-paste step and going stale the moment the
instance is stopped/started or recreated (AWS reassigns a new public IP each time).

This project removes that manual step entirely:

| | Static inventory (manual) | This project (dynamic) |
|---|---|---|
| Where the IP lives | Hand-typed into `inventory.ini` | Never stored — queried live from the AWS API on every run |
| After `terraform destroy` + `apply` | Must manually update the IP | Works immediately, no edits needed |
| After EC2 stop/start (new IP) | Breaks until manually fixed | Works immediately, no edits needed |
| Scales to multiple instances | Manual editing per host | Automatic, grouped by tags (`Role`, etc.) |

## Project Structure

```
folder/
├── app/
│   ├── index.html       # Campus Lost & Found portal (report/browse items)
│   └── Dockerfile        # nginx:alpine, serves index.html on port 80
├── terraform/
│   ├── main.tf            # EC2 instance + security group, tagged for discovery
│   ├── variables.tf       # region, instance type, key name, project tags
│   └── outputs.tf         # public IP, instance ID, security group ID
├── ansible/
│   ├── aws_ec2.yml        # dynamic inventory plugin config (filters by tags)
│   ├── ansible.cfg         # points Ansible at aws_ec2.yml by default
│   ├── group_vars/all.yml # SSH user + key path, applied to all discovered hosts
│   └── deploy.yml         # installs Docker, copies app, builds + runs container
├── fa1-key.pem             # SSH private key (gitignored, not committed)
└── .gitignore
```

## Setup Instructions

### Prerequisites
- Terraform, AWS CLI installed and configured (`aws configure`) with an IAM user that has EC2 permissions
- An EC2 key pair created in the AWS Console, downloaded as `fa1-key.pem` into this folder
- Ansible must run from a Linux environment (WSL on Windows) since it has no native Windows control-node support
- Python `boto3`/`botocore` and the `amazon.aws` Ansible collection installed in that environment

### 1. Provision infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 2. Verify dynamic inventory discovers the instance
```bash
cd ../ansible
export ANSIBLE_CONFIG="$(pwd)/ansible.cfg"
ansible-inventory -i aws_ec2.yml --graph
ansible all -i aws_ec2.yml -m ping
```

### 3. Deploy the application
```bash
ansible-playbook -i aws_ec2.yml deploy.yml
```

### 4. Open the app
Visit `http://<EC2_PUBLIC_IP>` (get the IP via `terraform output instance_public_ip`, or it's
resolved automatically by the dynamic inventory — no need to look it up manually for Ansible
to work).

### 5. Tear down (when done)
```bash
cd ../terraform
terraform destroy
```

## Result

The project automates AWS infrastructure provisioning with Terraform, live host discovery
and configuration with Ansible's dynamic inventory plugin, and application deployment with
Docker — with no manual IP handling anywhere in the pipeline.

**Terraform = CREATE | Ansible = DISCOVER + CONFIGURE | Docker = RUN**
