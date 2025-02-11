provider "aws" {
  region = "eu-west-3"  # Remplacez par votre région AWS
}

# Clé SSH unique pour toutes les instances
resource "aws_key_pair" "my_key_pair" {
  key_name   = "cle-terraform"  # Nom de votre clé SSH
  public_key = file("\\wsl$\Ubuntu\home\dark\terraform")  # Remplacez par le chemin de votre clé publique
}

# VPC (si nécessaire)
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Sous-réseau pour le backend
resource "aws_subnet" "my_backend_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-3a"
  map_public_ip_on_launch = true
}

# Sous-réseau pour le frontend
resource "aws_subnet" "my_frontend_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-3b"
  map_public_ip_on_launch = true
}

# Groupe de sécurité pour les instances EC2
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow SSH and ICMP"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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

# Instance EC2 Backend (Application)
resource "aws_instance" "backend" {
  ami             = "ami-06e02ae7bdac6b938"  # Remplacez par l'AMI d'Ubuntu ou autre
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.my_key_pair.key_name  # Utilisation de la clé SSH créée
  subnet_id       = aws_subnet.my_backend_subnet.id  # Utilisation du sous-réseau backend
  security_groups = [aws_security_group.ec2_sg.name]

  tags = {
    Name = "Backend"
  }

  provisioner "file" {
    source      = "setup_backend.yml"
    destination = "/tmp/setup_backend.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y python3-pip",
      "sudo apt-get install -y ansible",
      "ansible-playbook /tmp/setup_backend.yml"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.backend.public_ip
      user        = "ubuntu"
      private_key = file("/home/user/.ssh/id_rsa")  # Remplacez par le chemin de votre clé privée
    }
  }
}

# Instance EC2 Frontend (Application)
resource "aws_instance" "frontend" {
  ami             = "ami-06e02ae7bdac6b938"  # Remplacez par l'AMI d'Ubuntu ou autre
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.my_key_pair.key_name  # Utilisation de la clé SSH créée
  subnet_id       = aws_subnet.my_frontend_subnet.id  # Utilisation du sous-réseau frontend
  security_groups = [aws_security_group.ec2_sg.name]

  tags = {
    Name = "Frontend"
  }

  provisioner "file" {
    source      = "setup_frontend.yml"
    destination = "/tmp/setup_frontend.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y python3-pip",
      "sudo apt-get install -y ansible",
      "ansible-playbook /tmp/setup_frontend.yml"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.frontend.public_ip
      user        = "ubuntu"
      private_key = file("/home/user/.ssh/id_rsa")  # Remplacez par le chemin de votre clé privée
    }
  }
}

# DB Subnet Group pour la base de données RDS
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name        = "my-db-subnet-group"
  subnet_ids  = [aws_subnet.my_backend_subnet.id, aws_subnet.my_frontend_subnet.id]
  description = "DB Subnet Group for RDS instance"
}

# Instance RDS MySQL pour la base de données
resource "aws_db_instance" "my_db" {
  allocated_storage    = 20
  db_name             = "mydatabase"
  engine              = "mysql"
  engine_version      = "8.0"
  instance_class      = "db.t2.micro"
  username            = "admin"
  password            = "password123"
  db_subnet_group_name = aws_db_subnet_group.my_db_subnet_group.name
  multi_az            = false
  storage_type        = "gp2"
  publicly_accessible = true
  skip_final_snapshot = true

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]  # Utilisation du groupe de sécurité pour la DB

  tags = {
    Name = "MyDatabase"
  }
}

# Bucket S3
resource "aws_s3_bucket" "my_bucket" {
  bucket = "mon-bucket-test-terraform-unique-12345"  # Nom unique du bucket
}

