terraform {
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 4.0"
      }
    }
}
  
  
provider "aws" {
    profile = "default"
    region  = "us-east-1"
}
  
  // VPC
  
resource "aws_vpc" "my_vpc" {
    cidr_block           = "10.0.0.0/16"
    enable_dns_support   = true
    enable_dns_hostnames = true
  
    tags = {
      Name = "main-vpc"
    }
}
  
  // Public Subnet
  
resource "aws_subnet" "public_subnet1" {
    vpc_id                  = aws_vpc.my_vpc.id
    cidr_block              = "10.0.0.0/18"
    map_public_ip_on_launch = true
    availability_zone       = "us-east-1a"
  
    tags = {
      Name = "pubic-subnet1"
    }
}
  
resource "aws_subnet" "public_subnet2" {
    vpc_id                  = aws_vpc.my_vpc.id
    cidr_block              = "10.0.64.0/18"
    map_public_ip_on_launch = true
    availability_zone       = "us-east-1b"
  
    tags = {
      Name = "pubic-subnet2"
    }
}
  
  // Private Subnet
  
resource "aws_subnet" "private_subnet1" {
    vpc_id                  = aws_vpc.my_vpc.id
    cidr_block              = "10.0.128.0/18"
    map_public_ip_on_launch = true
    availability_zone       = "us-east-1a"
  
    tags = {
      Name = "private-subnet1"
    }
}
  
resource "aws_subnet" "private_subnet2" {
    vpc_id                  = aws_vpc.my_vpc.id
    cidr_block              = "10.0.192.0/18"
    map_public_ip_on_launch = true
    availability_zone       = "us-east-1b"
  
    tags = {
      Name = "private-subnet2"
    }
}
  
  // Internet gateway
  
resource "aws_internet_gateway" "my_gateway" {
    vpc_id = aws_vpc.my_vpc.id
    tags = {
      Name = "my-gateway"
    }
}
  
  // Elastic IP
  
resource "aws_eip" "nat_eip" {
    vpc        = true
    depends_on = [aws_internet_gateway.my_gateway]
    tags = {
      Name = "my-eip"
    }
}
  
  // NAT gateway
  
resource "aws_nat_gateway" "my_gateway" {
    allocation_id = aws_eip.nat_eip.id
    subnet_id     = aws_subnet.public_subnet1.id
    depends_on    = [aws_internet_gateway.my_gateway]
    tags = {
      Name = "my-nat"
    }
}
  
  // PUBLIC Route
resource "aws_route_table" "my_public_route_table" {
    vpc_id = aws_vpc.my_vpc.id
    tags = {
      Name = "public-route"
    }
  
}
  
resource "aws_route" "public_route" {
    route_table_id         = aws_route_table.my_public_route_table.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.my_gateway.id
}
  
  // PRIVATE Route 
resource "aws_route_table" "my_private_route_table" {
    vpc_id = aws_vpc.my_vpc.id
    tags = {
      Name = "private-route"
    }
}
  
resource "aws_route" "private_route" {
    route_table_id         = aws_route_table.my_private_route_table.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id         = aws_nat_gateway.my_gateway.id
}
  
  // Public Route table Assocation
  
resource "aws_route_table_association" "public_subnet_1" {
    subnet_id      = aws_subnet.public_subnet1.id
    route_table_id = aws_route_table.my_public_route_table.id
}
  
resource "aws_route_table_association" "public_subnet_2" {
    subnet_id      = aws_subnet.public_subnet2.id
    route_table_id = aws_route_table.my_public_route_table.id
}
  
  
  // Private Route table Assocation
  
resource "aws_route_table_association" "private_subnet_1" {
    subnet_id      = aws_subnet.private_subnet1.id
    route_table_id = aws_route_table.my_private_route_table.id
}
  
resource "aws_route_table_association" "private_subnet_2" {
    subnet_id      = aws_subnet.private_subnet2.id
    route_table_id = aws_route_table.my_private_route_table.id
}


// Security group for EC2 instances
resource "aws_security_group" "security" {
    vpc_id = aws_vpc.my_vpc.id
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
  
    egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  
    tags = {
      Name = "allow_tls"
    }
}

// AMI
data "aws_ami" "amazon-linux-2" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

// SSH-KEY
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("/root/.ssh/id_rsa.pub")
}

// Template for EC2 instances
resource "aws_launch_configuration" "my_configuration" {
    name_prefix   = "terraform-"
    image_id      =  data.aws_ami.amazon-linux-2.id
    instance_type          = "t2.micro"
    key_name               = aws_key_pair.deployer.key_name
    security_groups = [aws_security_group.security.id]
    user_data              = file("install_apache.sh")

    lifecycle {
        create_before_destroy = true
    } 
}

// Security groups for LB
resource "aws_security_group" "lbsg" {
    vpc_id = aws_vpc.my_vpc.id
    ingress {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  
    egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  
    tags = {
      Name = "my_lb"
    }
  
}


// Elastic Load balancer
resource "aws_elb" "my_elb" {
    name                 = "myloadbalancer"
    security_groups      = [aws_security_group.lbsg.id]
    subnets              = [aws_subnet.public_subnet1.id,aws_subnet.public_subnet2.id]
    cross_zone_load_balancing   = true
    
    health_check {
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 3
        interval = 30
        target = "HTTP:80/"
    }
    
    listener {
        instance_port      = 80
        instance_protocol  = "http"
        lb_port            = 80
        lb_protocol        = "http"
    }

}

// Load balancer
resource "aws_autoscaling_group" "my_lb" {
    name                   = "my-load-balancer"
    max_size               = 4
    min_size               = 2
    health_check_type      = "ELB"
    load_balancers         = [aws_elb.my_elb.id]
    launch_configuration   = aws_launch_configuration.my_configuration.name

    lifecycle {
        create_before_destroy = true
    }

    vpc_zone_identifier     = [aws_subnet.public_subnet1.id,aws_subnet.public_subnet2.id]


    enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
    ]

    metrics_granularity = "1Minute"
}
