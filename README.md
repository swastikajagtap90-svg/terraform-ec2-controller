# Terraform EC2 Controller Lab

This project is a learning lab that uses Terraform on your local computer to create an EC2 controller. The controller receives an IAM instance profile and can be used to run a second Terraform configuration that creates a test S3 bucket.

## Files

- `main.tf` — AWS resources and nested Terraform configuration
- `variables.tf` — configurable region, instance type, and SSH source IP
- `outputs.tf` — controller IP, SSH command, and planned bucket name
- `user_data.sh.tftpl` — installs Terraform on the Ubuntu controller
- `terraform.tfvars.example` — example variable values; copy to `terraform.tfvars`
- `.gitignore` — excludes local state, plans, keys, and credentials

## Before you start

1. Install Terraform and AWS CLI on your local computer.
2. Configure AWS CLI with an IAM identity intended for this lab. Do not use the AWS root user for routine CLI work.
3. Ensure that identity has the EC2 and IAM permissions required to create the resources in `main.tf`, including `iam:ListAttachedRolePolicies` and `iam:ListInstanceProfilesForRole`. Follow least privilege and review your organization's requirements.
4. Copy `terraform.tfvars.example` to `terraform.tfvars`.
5. Replace `REPLACE_WITH_YOUR_PUBLIC_IPV4/32` with your current public IPv4 address followed by `/32`. Do not use `0.0.0.0/0` for SSH.
6. Do not commit `terraform.tfvars`, access keys, private keys, or Terraform state to GitHub.

## Validate and preview

Run these commands from this directory:

```powershell
terraform init
terraform fmt -recursive
terraform validate
terraform plan
```

Review the full plan before applying. The first deployment creates AWS resources and may incur charges.

## Deploy

Only after reviewing the plan and confirming you want to create the resources:

```powershell
terraform apply
```

Type `yes` only after reviewing the proposed actions.

After deployment completes, use the `ssh_command` output to connect. If the controller needs time to finish bootstrapping, wait a few minutes before running the nested configuration.

## Run nested Terraform on the controller

Connect using the output SSH command, then run:

```bash
cd /home/ubuntu/secondary-infra
terraform init
terraform plan
terraform apply
```

Review the nested plan before applying it.

## Cleanup — order matters

First destroy the nested S3 bucket from the controller:

```bash
cd /home/ubuntu/secondary-infra
terraform destroy
```

Then exit SSH and destroy the outer resources from your local project folder:

```powershell
terraform destroy
```

Review each destroy plan before confirming. Do not delete local Terraform state while resources still exist; state is needed to manage and clean them up.

## Security notes

- SSH is restricted to the single IPv4 CIDR you provide.
- The instance profile requires IMDSv2.
- The generated private key is written locally as `tf-runner-key.pem`; keep it private and never upload it to GitHub.
- The nested S3 policy is intended for buckets named `nested-tf-bucket-*`, plus bucket listing. Review and adapt permissions before using outside a lab.
- The example uses a default VPC. If your account has no default VPC, update the network configuration before deploying.
- Always review Terraform plans; a replacement or destroy action should be understood before approval.
