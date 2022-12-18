terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}


provider "aws" {
  region = "eu-west-2"
#  access_key = "" #environment variable
#  secret_key = ""
}

#1 Create VPC #google:terraform aws vpc
##########################################
resource "aws_vpc" "the_vpc" {
  cidr_block       = "10.0.0.0/16"
  tags = {
    Name = "The VPC"
  }
}

#2 Create internet gateway #google:terraform aws internet gateway
##########################################
resource "aws_internet_gateway" "the_gateway" {
  vpc_id = aws_vpc.the_vpc.id
  tags = {
    Name = "main"
  }
}

#3 Create custom route table # google: terraform aws route table
##########################################
resource "aws_route_table" "the_route_table" {
  vpc_id = aws_vpc.the_vpc.id

  route {
    cidr_block = "0.0.0.0/0" #send this network's traffic to the gateway. 0.0.0.0/0 means everything.
    gateway_id = aws_internet_gateway.the_gateway.id #The just created gateway's ID
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.the_gateway.id
  }

  tags = {
    Name = "The route table"
  }
}

#4 Create a Subnet # google: terraform aws subnet
##########################################
resource "aws_subnet" "the_subnet" {
  vpc_id     = aws_vpc.the_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-2a" #do not really need. 

  tags = {
    Name = "The Subnet"
  }
}

#5 Associate the subnet with the route table.# google:terraform aws route table association
##########################################
resource "aws_route_table_association" "the_association" {
  subnet_id      = aws_subnet.the_subnet.id
  route_table_id = aws_route_table.the_route_table.id

}

#6 Create security group to allow ports(22,80,443).# google: terraform aws security group
resource "aws_security_group" "allow_22_80_443" {
  name        = "allow_ssh_http_https"
  description = "Allow basic traffic"
  vpc_id      = aws_vpc.the_vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]#from which network. (lista) 
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]#it should be my own IP address.
    ipv6_cidr_blocks = ["::/0"]
  }  

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"#any protocol
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Allow Basic Traffic"
  }
}
#7 Create an interface with an IP in the subnet that was created in step 4# google: terraform aws create interface
resource "aws_network_interface" "the_interface" {
  subnet_id       = aws_subnet.the_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_22_80_443.id]

#  attachment {
#    instance     = aws_instance.test.id
#    device_index = 1
#  }  #Can be specified the instance here, or can be specified in the declaration of the instance.
}

#8 Assign an elastic IP address to the network interface what just created in step 7.# google: terraform aws assign elastic ip address
resource "aws_eip" "getting_public_ip" {
  vpc                       = true #if it is in vpc
  network_interface         = aws_network_interface.the_interface.id
  associate_with_private_ip = "10.0.1.50"
  #private_ips = ["10.0.0.10", "10.0.0.11"] #if more than one
  depends_on = [#should work without it, but must be declared explicitly, because sometimes drops error, because of missing gateway
    aws_internet_gateway.the_gateway #the whole object is referenced not just its ID
  ]
}

#9 Create an instanve and install/enable apache# google:aws terraform instance ubuntu
resource "aws_instance" "the-server" {
  ami           = "ami-07c2ae35d31367b3e" 
  instance_type = "t2.micro"
  availability_zone = "eu-west-2a" #must be explicitly setted as the subnet. (wont work if they are not in the same data center.)
  key_name =  "whereispem?"



  network_interface {
    network_interface_id = aws_network_interface.the_interface.id
    device_index         = 0 #just numbering the device. 0,1,2 etc...
  }

 # credit_specification {
  #  cpu_credits = "unlimited"
 # }

  user_data = <<-EOF
            #!/bin/bash
            sudo apt update -y
            sudo apt install apache2 -y
            sudo systemctl start apache2
            sudo bash -c 'echo your web server > /var/www/html/index.html'
            EOF

    tags = {

      Name = "the web server"
    }


}






