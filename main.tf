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
  vpc_id     = "${data.aws_vpc.main.id}"
  cidr_block = "10.20.0.0/25"
  availability_zone = "eu-west-1a"
  //tags = "${local.tags}"

}


resource "aws_subnet" "az2" {
  vpc_id     = "${data.aws_vpc.main.id}"
  cidr_block = "10.20.0.128/25"
  availability_zone = "eu-west-1b"
  //tags = "${local.tags}"

}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic"
  vpc_id      = "${data.aws_vpc.main.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  //tags = "${local.tags}"
}

resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow all inbound traffic"
  vpc_id      = "${data.aws_vpc.main.id}"

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

  
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks = [ "0.0.0.0/0"]
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
  //tags = "${local.tags}"  
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
  //tags = "${local.tags}"
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
  //tags = "${local.tags}"  
}   
