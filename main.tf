provider "aws" {
  region = "us-east-2"
}

variable "instance_type" {
  description = "Type of instance to be created: t2.micro, t2.nano"
  default     = "t2.micro"
  type        = string
}
variable "ami" {
  default = "ami-0fb653ca2d3203ac1"
}

# resource "aws_instance" "ec2_ubuntu" {
#   instance_type = var.instance_type # 1 GB RAM & 1 vCPU
#   ami           = var.ami           # 8 GB SSD
#   tags = {
#     Name   = "kmayer"
#     Client = "thinknyx"
#   }
# }

resource "aws_instance" "ec2_ubuntu_multiple" {
  count         = 1
  instance_type = var.instance_type # 1 GB RAM & 1 vCPU
  ami           = var.ami           # 8 GB SSD
  tags = {
    Name   = "kmayer_${count.index}"
    Client = "thinknyx"
    Count  = count.index
  }
  key_name = aws_key_pair.key_pair.key_name #we can't attach keypair with the running instance, terraform will destroy and recreate the EC2 server
}

provider "tls" {}

resource "tls_private_key" "keypair" {
  algorithm = "RSA"
  rsa_bits = "2048"
}

resource "aws_key_pair" "key_pair" {
  key_name = "kmayer"
  public_key = tls_private_key.keypair.public_key_openssh
}

data "aws_vpc" "default" {
  default = true
}

data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "ssh" {
  for_each = toset([ "22", "80" ])
  type = "ingress"
  cidr_blocks = [ "0.0.0.0/0" ]
  from_port = each.value
  to_port = each.value
  protocol = "TCP"
  description = "port"
  security_group_id = data.aws_security_group.default.id
}

provider "local" {}

resource "local_file" "aws_server_private_key" {
  filename = "c:/users/kulbh/.ssh/${aws_key_pair.key_pair.key_name}.pem"
  content = tls_private_key.keypair.private_key_pem
}

provider "null" {}

resource "null_resource" "install_apache" {
  # triggers = {
  #   "build" = timestamp()
  # }
  depends_on = [
    null_resource.copy_html
  ]
  count = 1
  provisioner "remote-exec" {
    connection {
      type = "ssh"
      user = "ubuntu"
      host = aws_instance.ec2_ubuntu_multiple[count.index].public_ip
      private_key = tls_private_key.keypair.private_key_pem
    }
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y apache2",
      "sudo cp /tmp/index.html /var/www/html/index.html"
    ]
  }
}

resource "null_resource" "access_apache" {
  depends_on = [
    null_resource.install_apache
  ]
  count = 1
  provisioner "local-exec" {
    command = "curl http://${aws_instance.ec2_ubuntu_multiple[count.index].public_ip}:80"
  }
}

resource "null_resource" "copy_html" {
  count = 1
  provisioner "file" {
    connection {
      type = "ssh"
      user = "ubuntu"
      host = aws_instance.ec2_ubuntu_multiple[count.index].public_ip
      private_key = tls_private_key.keypair.private_key_pem
    }
    source = "sample2.html"
    destination = "/tmp/index.html"
  }
}
