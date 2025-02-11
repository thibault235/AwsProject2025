provider "aws" {
  region = "eu-west-3"  # Remplace par ta région AWS
}

# Clé SSH unique pour les instances
resource "aws_key_pair" "my_key_pair" {
  public_key = file("/home/dark/.ssh/id_rsa.pub")  # Chemin absolu vers ta clé publique
}

# VPC
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

# Groupe de sécurité pour les instances et RDS
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Security group pour instances EC2 et RDS"
  vpc_id      = aws_vpc.my_vpc.id

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

# Instance Backend
resource "aws_instance" "backend" {
  ami           = "ami-0f538382b0c516a7c"  # AMI Amazon Linux 2 (remplace si besoin)
  instance_type = "t2.micro"
  key_name      = aws_key_pair.my_key_pair.key_name
  subnet_id     = aws_subnet.my_backend_subnet.id

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  tags = {
    Name = "Backend-Instance"
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("/home/dark/.ssh/id_rsa")
    host        = self.public_ip
  }
}

# Instance Frontend
resource "aws_instance" "frontend" {
  ami           = "ami-0f538382b0c516a7c"  # AMI Amazon Linux 2 (remplace si besoin)
  instance_type = "t2.micro"
  key_name      = aws_key_pair.my_key_pair.key_name
  subnet_id     = aws_subnet.my_frontend_subnet.id

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  tags = {
    Name = "Frontend-Instance"
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("/home/dark/.ssh/id_rsa")
    host        = self.public_ip
  }
}

# Groupe de sous-réseaux pour la base de données
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.my_backend_subnet.id, aws_subnet.my_frontend_subnet.id]

  lifecycle {
    prevent_destroy = true
  }
}

# Instance RDS
resource "aws_db_instance" "my_db" {
  identifier             = "my-rds-db-instance"
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0.34"
  instance_class         = "db.t3.micro"
  username               = "admin"
  password               = "mypassword123"
  db_subnet_group_name   = aws_db_subnet_group.my_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  skip_final_snapshot    = true

  tags = {
    Name = "MyDatabase"
  }
}

# Bucket S3 pour le backend
resource "aws_s3_bucket" "backend_bucket" {
  bucket = "mon-bucket-test-terraform-unique-125946135"
  tags = {
    Name        = "BackendBucket"
    Environment = "Dev"
  }

  object_lock_enabled = false
}

resource "aws_s3_bucket_public_access_block" "backend_bucket_block" {
  bucket = aws_s3_bucket.backend_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
