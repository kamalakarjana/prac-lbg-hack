# Terraform Azure WebApp Deployment

This project deploys a 2-tier web application on Azure using Terraform.

## Prerequisites

1. Azure CLI installed and logged in
2. Terraform installed
3. Azure Service Principal credentials

## Setup

1. Clone this repository
2. Create `azure_credentials.tfvars` file from the example:
   ```bash
   cp azure_credentials.tfvars.example azure_credentials.tfvars