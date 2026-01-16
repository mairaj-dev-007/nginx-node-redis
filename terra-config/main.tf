#the main IAC

provider "aws" {
  region = "us-east-1"
}
variable "terraform_pat" {
  description = "GitHub Personal Access Token for cloning private repo"
  type        = string
  sensitive   = true
}

resource "aws_security_group" "web_sg" {
  name        = "nginx-web-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
  from_port   = 3000
  to_port     = 3000
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "ubuntu" {
    most_recent = true
    owners = ["099720109477"]
  
      filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
      }

      filter {
        name   = "virtualization-type"
        values = ["hvm"]
      }
    }

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
              #!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "--- System Update ---"
apt-get update -y
apt-get install -y docker.io git

# Install docker-compose v2
apt-get install -y docker-compose-plugin

echo "--- Start Docker ---"
systemctl start docker
systemctl enable docker
sleep 10

echo "--- Cloning App ---"
rm -rf /home/ubuntu/nginx-node-redis
sudo -u ubuntu git clone https://${var.terraform_pat}@github.com/mairaj-dev-007/nginx-node-redis.git /home/ubuntu/nginx-node-redis

echo "--- Launching App ---"
cd /home/ubuntu/nginx-node-redis
docker compose up -d --build

echo "--- Script Finished ---"

              EOF

  tags = {
    Name = "nginx-docker-instance"
  }
}

output "public_ip" {
  value       = aws_instance.web.public_ip
}
