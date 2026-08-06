packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "windows" {
  region         = "us-east-1"
  instance_type  = "t3.medium"
  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_use_ssl   = false
  winrm_insecure  = true
  winrm_timeout   = "45m"

  source_ami_filter {
    filters = {
      name                = "Windows_Server-2022-English-Full-Base-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["801119661308"] # Official Amazon AWS AMI Owner ID
  }

  ami_name       = "Enlyte-Authorized-AMI-Win2022-v${formatdate("YYYYMMDD-hhmm", timestamp())}"
  user_data_file = "../Scripts/bootstrap-winrm.ps1"

  tags = {
    Name       = "Enlyte-Authorized-AMI-Win2022"
    Created_By = "Jenkins Pipeline"
  }
}

build {
  sources = ["source.amazon-ebs.windows"]

  # 1. Patch OS
  provisioner "powershell" {
    script = "../scripts/install-updates.ps1"
  }

  # 2. Sanitize Environment Variables (Guardrail)
  provisioner "powershell" {
    script = "../scripts/sanitize-env.ps1"
  }

  # 3. Sysprep
  provisioner "powershell" {
    inline = [
      "C:\\Program Files\\Amazon\\EC2Launch\\ec2launch.exe sysprep"
    ]
  }
}