# FA1 – Automated Deployment of Campus Lost & Found Portal

Automates AWS infrastructure provisioning (Terraform), server configuration (Ansible with
dynamic inventory), and application deployment (Docker) for a simple Lost & Found web portal.

## Stack
- **Terraform** – creates AWS EC2 instance + security group, tags the instance for discovery.
- **Ansible (dynamic inventory)** – discovers the tagged EC2 instance live from AWS, installs
  Docker, deploys the app. No manually edited inventory file.
- **Docker** – packages and runs the static site via nginx.

## Status
Work in progress — see project phases in the working notes.
