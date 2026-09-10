packer {
  required_version = ">= 1.15.3"

  required_plugins {
    amazon = {
      version = ">= 1.8.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# --- Variables ---

variable "tags_name" {
  type    = string
  default = "Enlyte-Authorized-AMI-Win2025"
}

variable "tags_created_by" {
  type    = string
  default = "wintel"
}

variable "tags_application_owner" {
  type    = string
  default = "cor"
}

variable "tags_purpose" {
  type    = string
  default = "infrastructure services"
}

variable "tags_product" {
  type    = string
  default = "win2025_ami"
}

variable "tags_environment" {
  type    = string
  default = "prod"
}

variable "tags_owner" {
  type    = string
  default = "wintel@mitchell.com"
}

variable "tags_create_auto_alarms" {
  type    = string
  default = "no"
}

# Official AWS Windows Server 2025 Base AMI defaults
variable "source_ami" {
  type    = string
  default = "Windows_Server-2025-English-Full-Base-*"
}

variable "source_ami_owner" {
  type    = string
  default = "801119661308" # Official AWS Owner ID
}

variable "ami_purpose" {
  type    = string
  default = "win2025_server"
}

variable "ami_description" {
  type    = string
  default = "CIS AMI Enlyte Authorized Win2025 server"
}

variable "awsAccount" {
  type    = string
  default = "corSharedServicesProd"
}

variable "awsRegion" {
  type    = string
  default = "us-east-1"
}

variable "vpc_id" {
  type    = string
  default = "vpc-0824b420556f8605e"
}

variable "subnet_id" {
  type    = string
  default = "subnet-0918ee71a565b26ba"
}

variable "security_group_id" {
  type    = string
  default = "sg-0281f71e0e7b6d55a"
}

variable "instance_type" {
  type    = string
  default = "t3.xlarge"
}

variable "root_volume_size" {
  type    = number
  default = 100
}

variable "communicator" {
  type    = string
  default = "winrm"
}

variable "winrm_port" {
  type    = number
  default = 5986
}

variable "winrm_timeout" {
  type    = string
  default = "30m"
}

variable "winrm_insecure" {
  type    = bool
  default = true
}

variable "winrm_use_ssl" {
  type    = bool
  default = true
}

variable "admin_user" {
  type    = string
  default = "Administrator"
}

variable "admin_password" {
  type      = string
  default   = "admin_password"
  sensitive = true
}

variable "pause_before_connecting" {
  type    = string
  default = "10m"
}

variable "max_retries" {
  type    = number
  default = 30
}

variable "custom_kms_key" {
  type    = string
  default = "7d0fcd44-6c19-4eb5-a255-23acade29d2f"
}

# --- Local Variables & Dynamic AMI Chaining Logic ---

locals {
  timestamp   = formatdate("YYYYMM", timestamp())
  create_date = formatdate("MM/DD/YYYY", timestamp())
}

# 1. Primary Lookup: Search for custom image created during active month
data "amazon-ami" "internal_current_month" {
  filters = {
    virtualization-type = "hvm"
    name                = "${var.tags_name}-v${local.timestamp}*"
    root-device-type    = "ebs"
  }
  owners      = ["self"]
  most_recent = true
  region      = var.awsRegion
}

# 2. Fallback Lookup: Search for official AWS Windows Server 2025 Base AMI
data "amazon-ami" "aws_official_base" {
  filters = {
    virtualization-type = "hvm"
    name                = var.source_ami
    root-device-type    = "ebs"
  }
  owners      = [var.source_ami_owner]
  most_recent = true
  region      = var.awsRegion
}

locals {
  # Safe extraction of attributes from internal AMI
  internal_ami_id    = try(data.amazon-ami.internal_current_month.id, "")
  internal_ami_name  = try(data.amazon-ami.internal_current_month.name, "")
  internal_ami_owner = try(data.amazon-ami.internal_current_month.owner_id, "")

  # Flag checking if a custom AMI exists in 'self' for active month
  has_internal_ami = local.internal_ami_id != ""

  # Dynamic AMI Chaining Choice
  selected_source_ami_id    = local.has_internal_ami ? local.internal_ami_id : data.amazon-ami.aws_official_base.id
  selected_source_ami_name  = local.has_internal_ami ? local.internal_ami_name : data.amazon-ami.aws_official_base.name
  selected_source_ami_owner = local.has_internal_ami ? local.internal_ami_owner : data.amazon-ami.aws_official_base.owner_id

  # Version calculation logic (vYYYYMM-1 for initial run, increments vYYYYMM-2, vYYYYMM-3 for subsequent runs)
  latest_version      = local.has_internal_ami ? try(regex("-v\\d{6}-(\\d+)$", local.internal_ami_name)[0], "0") : "0"
  incremented_version = format("%d", parseint(local.latest_version, 10) + 1)
  next_version        = local.incremented_version

  # Cleaned AMI Name string replacing any disallowed characters with a hyphen
  raw_ami_name   = "${var.tags_name}-v${local.timestamp}-${local.next_version}"
  clean_ami_name = regex_replace(local.raw_ami_name, "[^a-zA-Z0-9()[\\] ./'@_-]", "-")
}

# --- Source Configuration ---

source "amazon-ebs" "windows_buildami" {
  ami_name                = local.clean_ami_name
  ami_description         = var.ami_description
  source_ami              = local.selected_source_ami_id
  instance_type           = var.instance_type
  region                  = var.awsRegion
  vpc_id                  = var.vpc_id
  subnet_id               = var.subnet_id
  security_group_id       = var.security_group_id
  communicator            = var.communicator
  winrm_username          = var.admin_user
  winrm_password          = var.admin_password
  winrm_port              = var.winrm_port
  winrm_timeout           = var.winrm_timeout
  winrm_insecure          = var.winrm_insecure
  winrm_use_ssl           = var.winrm_use_ssl
  pause_before_connecting = var.pause_before_connecting
  max_retries             = var.max_retries
  deprecate_at            = timeadd(timestamp(), "43200h")

  # Bootstrapping WinRM via User Data script
  user_data_file = "../Scripts/bootstrap-winrm.ps1"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    delete_on_termination = true
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    kms_key_id            = var.custom_kms_key
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    "Name"             = local.clean_ami_name
    "source_ami_id"    = local.selected_source_ami_id
    "source_ami_name"  = local.selected_source_ami_name
    "source_ami_owner" = local.selected_source_ami_owner
    "project"          = "ccoe"
    "ami_purpose"      = var.ami_purpose
    "patch-owner"      = var.tags_owner
    "operatingSystem"  = "Windows Server 2025"
  }

  run_tags = {
    "Name"               = local.clean_ami_name
    "application-owner"  = var.tags_application_owner
    "purpose"            = var.tags_purpose
    "product"            = var.tags_product
    "environment"        = var.tags_environment
    "project"            = "ccoe"
    "create_auto_alarms" = var.tags_create_auto_alarms
    "patch-owner"        = var.tags_owner
    "operatingSystem"    = "Windows Server 2025"
  }

  run_volume_tags = {
    "Name"               = local.clean_ami_name
    "application-owner"  = var.tags_application_owner
    "purpose"            = var.tags_purpose
    "product"            = var.tags_product
    "environment"        = var.tags_environment
    "project"            = "ccoe"
    "create_auto_alarms" = var.tags_create_auto_alarms
    "patch-owner"        = var.tags_owner
    "operatingSystem"    = "Windows Server 2025"
  }
}

# --- Build Pipeline ---

build {
  sources = [
    "source.amazon-ebs.windows_buildami"
  ]

  # 1. Install Windows Updates (Executes install-updates.ps1 with auto-reboot support)
  provisioner "powershell" {
    script            = "../Scripts/install-updates.ps1"
    elevated_user     = var.admin_user
    elevated_password = build.Password
  }

  # 2. Restart target instance if updates require a reboot
  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  # 3. Sanitize System Environment Variables (Executes sanitize-env.ps1)
  provisioner "powershell" {
    script = "../Scripts/sanitize-env.ps1"
  }

  # 4. Sysprep / Generalize system before imaging
  provisioner "powershell" {
    script      = "./provisioners/scripts/run_sysprep.ps1"
    max_retries = 5
    pause_after = "120s"
  }

  post-processor "manifest" {
    custom_data = {
      ami_tags = "Key=source_ami_id,Value=${local.selected_source_ami_id} Key=source_ami_name,Value=${local.selected_source_ami_name} Key=source_ami_owner,Value=${local.selected_source_ami_owner} Key=project,Value=ccoe Key=ami_purpose,Value=${var.ami_purpose} Key=patch-owner,Value=${var.tags_owner}"
    }
  }
}