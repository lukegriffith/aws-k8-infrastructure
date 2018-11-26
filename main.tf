provider "aws" {
    region = "eu-west-1"
}


locals {
    tags = {
        Terraform = "true"
        Owner = "lg"
        Env = ["k8s"]
    }
    ami = "ami-0bdb1d6c15a40392c"
}


resource "aws_key_pair" "deployer" {
  key_name   = "configurer"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0OHF4w5Vu8nR9L79e5snJfPnIx8PkskFFp+5nR1o+czVUTGyk7GmVCQKzUlmqW2jCc4P7zn5JisthMZJCZdMyfQ3OABPE3XMucasUn/JdmhiDHtBwjnVBDdEHjPXyMWpzoBizLKCy3ST/eq2aSvQBCYIDbf6MnYmMhqVXyZj0KKEusSRkmhOiHCmybiTywHw48D18kFTfA2dCcyTIvR2LJkrYVVZ/ipBqSPsJFxKw+ZVyS/kEEMiaS7ZksvV02FB7VMUS1WMZO+W/xtqk4+3wihcmfq9lhKfk9tbvyu6HwBDDEMxXMJ8jpNp8t/e6M9qKcIGmXbTfIwJ7XkArEcBN lukem@DESKTOP-K4ROOO4"
}


//resource "aws_vpc" "main" {
//  cidr_block = "10.10.0.0/21"
//  tags {
//      Name = "k8sVPC"
//      Terraform = "true"
//      Owner = "lg"
//      Env = "k8s"
//  }
//}
//

data "aws_vpc" "main" {
  id = "vpc-0217640c851aa58b9"
}


resource "aws_subnet" "az1" {
  vpc_id     = "${data.aws_vpc_main.id}"
  cidr_block = "10.10.1.0/24"
  availability_zone = "eu-west-1a"
  tags = "${local.tags}"

  depends_on = ["aws_internet_gateway.gw"]
}


resource "aws_subnet" "az2" {
  vpc_id     = "${data.aws_vpc_main.id}"
  cidr_block = "10.10.2.0/24"
  availability_zone = "eu-west-1b"
  tags = "${local.tags}"

  depends_on = ["aws_internet_gateway.gw"]
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic"
  vpc_id      = "${data.aws_vpc_main.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${local.tags}"
}

resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow all inbound traffic"
  vpc_id      = "${data.aws_vpc_main.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self = "true"
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    self = "true"
  }
}

module "ec2_cluster_az1" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name           = "kubeNode"
  instance_count = 3

  ami                    = "${local.ami}"
  instance_type          = "t2.medium"
  key_name               = "configurer"
  monitoring             = false
  vpc_security_group_ids = ["${aws_security_group.allow_all.id}"]
  subnet_id              = "${aws_subnet.az1.id}"
  tags = "${local.tags}"  
}   


module "ec2_cluster_az2" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name           = "kubeNode"
  instance_count = 3

  ami                    = "${local.ami}"
  instance_type          = "t2.medium"
  key_name               = "configurer"
  monitoring             = false
  vpc_security_group_ids = ["${aws_security_group.allow_all.id}"]
  subnet_id              = "${aws_subnet.az2.id}"
  tags = "${local.tags}"
}   



module "bastion" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name           = "bastion"
  instance_count = 1
  associate_public_ip_address = "true"

  ami                    = "${local.ami}"
  instance_type          = "t2.micro"
  key_name               = "configurer"
  monitoring             = false
  vpc_security_group_ids = ["${aws_security_group.allow_ssh.id}", "${aws_security_group.allow_all.id}"]
  subnet_id              = "${aws_subnet.az1.id}"
  tags = "${local.tags}"  
}   


resource "aws_internet_gateway" "gw" {
  vpc_id = "${data.aws_vpc_main.id}"
  tags = "${local.tags}"
}

resource "aws_route_table" "route_table" {
  vpc_id = "${data.aws_vpc_main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = "${local.tags}"
}

resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.az1.id}"
  route_table_id = "${aws_route_table.route_table.id}"
}

resource "aws_route_table_association" "b" {
  subnet_id      = "${aws_subnet.az2.id}"
  route_table_id = "${aws_route_table.route_table.id}"
}



resource "aws_default_network_acl" "main" {
  default_network_acl_id  = "${data.aws_vpc_main.default_network_acl_id}"

  egress {
    protocol   = "tcp"
    rule_no    = 201
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  egress {
    protocol   = "tcp"
    rule_no    = 202
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  egress {
    protocol   = "tcp"
    rule_no    = 203
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 32768
    to_port    = 65535
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 101
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }


  ingress {
    protocol   = "tcp"
    rule_no    = 102
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }


  tags = "${local.tags}"
}   