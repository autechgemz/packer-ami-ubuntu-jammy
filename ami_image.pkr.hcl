packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.0"
    }
  }
}

variable "aws_region" {
  type    = string
  default = ""
}

variable "aws_subnet_id" {
  type    = string
  default = ""
}

variable "aws_vpc_id" {
  type    = string
  default = ""
}

data "amazon-ami" "autogenerated_1" {
  filters = {
    name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"]
  profile     = "default"
  region      = "${var.aws_region}"
}

locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

source "amazon-ebs" "autogenerated_1" {
  ami_name                    = "custom-base-ami-${local.timestamp}"
  associate_public_ip_address = true
  instance_type               = "t3.micro"
  profile                     = "default"
  region                      = "${var.aws_region}"
  source_ami                  = "${data.amazon-ami.autogenerated_1.id}"
  ssh_username                = "ubuntu"
  ssh_pty                     = true
  subnet_id                   = "${var.aws_subnet_id}"
  vpc_id                      = "${var.aws_vpc_id}"
}

build {
  sources = ["source.amazon-ebs.autogenerated_1"]

  provisioner "shell" {
    inline = [
      "cloud-init status --wait",
      "sudo apt-get update && sudo apt-get upgrade -y",
      "sudo apt-get install -y python3"]
  }

  provisioner "ansible" {
    user = "ubuntu"
    use_proxy = false
    playbook_file = "playbook.yml"
  }

  provisioner "shell" {
    inline = [
      "sudo truncate -s 0 /var/log/*log",
      "sudo cloud-init clean --machine-id"
      ]
  }

  provisioner "file" {
    source      = "bootstrap.cfg"
    destination = "/tmp/99-bootstrap.cfg"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/99-bootstrap.cfg /etc/cloud/cloud.cfg.d/99-bootstrap.cfg"
      ]
  }

}
