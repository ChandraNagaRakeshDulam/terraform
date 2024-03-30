provider "aws" {
  region = "us-east-1"
  
}

resource "aws_vpc" "tf-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "hr-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id     = aws_vpc.tf-vpc.id
 
}

#route table

resource "aws_route_table" "hr-route-table" {
  vpc_id = aws_vpc.tf-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "hr-route"
  }
}

#subnet

resource "aws_subnet" "subnet-1" {

    vpc_id =  aws_vpc.tf-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"

    tags = {
        Name = "hr-subnet"
    }
}

#associate subnet with route table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.hr-route-table.id
}

#create security group
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.tf-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
   }
   ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
   }
   ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
   }

   egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
   }

   tags = {
    Name = "allow_web"
   }
}

#network interface 

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

#8 assign an elastic ip

resource "aws_eip" "one" {
   vpc                       = true
   network_interface         = aws_network_interface.web-server-nic.id
   associate_with_private_ip = "10.0.1.50"
   depends_on                = [aws_internet_gateway.gw]
}

#9 ubuntu server

resource "aws_instance" "web-server-instance" {
  ami               = "ami-0c101f26f147fa7fd"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "hr-acces key"

  network_interface {
     device_index         = 0
     network_interface_id = aws_network_interface.web-server-nic.id
   }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF

  tags = {
     Name = "web-server"
   }
}


