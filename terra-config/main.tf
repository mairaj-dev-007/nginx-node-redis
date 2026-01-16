provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "web_sg" {
  name        = "nginx-web-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  # Allow HTTP, SSH, and your app ports
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
    from_port   = 81
    to_port     = 82
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6379
    to_port     = 6379
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
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type           = "t3.micro"
  vpc_security_group_ids  = [aws_security_group.web_sg.id]

  user_data = <<-EOF
#!/bin/bash
# Log everything for debugging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "--- System Update ---"
apt-get update -y

echo "--- Installing Docker and dependencies ---"
apt-get install -y docker.io git curl

# Remove old docker-compose if exists
apt-get remove -y docker-compose || true

# Install Docker Compose v2 plugin
mkdir -p ~/.docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.27.2/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose

# Start and enable Docker
systemctl start docker
systemctl enable docker

echo "--- Cloning App ---"
rm -rf /home/ubuntu/nginx-node-redis

# Clone your public repo
git clone https://github.com/mairaj-dev-007/nginx-node-redis.git /home/ubuntu/nginx-node-redis

cd /home/ubuntu/nginx-node-redis

echo "--- Launching App with Docker Compose v2 ---"
/usr/bin/docker compose up -d --build

echo "--- Script Finished ---"
EOF

  tags = {
    Name = "nginx-docker-instance"
  }
}

output "public_ip" {
  value = aws_instance.web.public_ip
}
