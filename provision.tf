# TODO variable
provider "aws" {
    access_key = "AKIAIKBVU7M5BSF5NEZA"
    secret_key = "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"
    region = "us-west-2"
}

variable "user" {
  default = "tball"
}

resource "aws_vpc" "postgresql_cluster_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags {
    X-Project = "Provisioning"
  }
}

resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.postgresql_cluster_vpc.id}"
}

resource "aws_route_table" "r" {
    vpc_id = "${aws_vpc.postgresql_cluster_vpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.gw.id}"
    }
    tags {
      X-Project = "Provisioning"
    }
}

resource "aws_main_route_table_association" "a" {
    vpc_id = "${aws_vpc.postgresql_cluster_vpc.id}"
    route_table_id = "${aws_route_table.r.id}"
}

resource "aws_security_group" "postgresql_cluster_sg" {
  vpc_id = "${aws_vpc.postgresql_cluster_vpc.id}"
  name = "postgresql_cluster_sg"
  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    X-Project = "Provisioning"
  }
}

resource "aws_subnet" "postgresql_cluster_subnet" {
    vpc_id = "${aws_vpc.postgresql_cluster_vpc.id}"
    cidr_block = "10.0.0.0/24"
    map_public_ip_on_launch = true
    tags {
      X-Project = "Provisioning"
    }
}

resource "aws_route_table_association" "postgresql_cluster_public_routing" {
    subnet_id = "${aws_subnet.postgresql_cluster_subnet.id}"
    route_table_id = "${aws_route_table.r.id}"
}

resource "aws_instance" "postgresql-1" {
  connection {
    user = "ec2-user"
    key_file = "/Users/tball/chef_repo/cookbooks/postgresql-bdr-cluster/.chef/keys/${var.user}@postgresql-bdr-cluster"
  }
  # Update our local cookbook cache
  provisioner "local-exec" {
    command = "berks update && rm -rf vendor/* && berks vendor vendor/"
  }
  # Make sure the remote node is connectable
  provisioner "remote-exec" {
    inline = "echo 'foo'"
  }
  # Forward 8889 to the remote host
  provisioner "local-exec" {
    command = "./forward.sh ${var.user} ${aws_instance.postgresql-1.public_ip}"
  }
  provisioner "chef" {
    server_url = "http://localhost:8889"
    validation_client_name = "tball"
    validation_key_path = "~/.chef/tball.pem"
    node_name = "postgresql-1.example.com"
    run_list = [ "postgresql-bdr-cluster::aws_instance_setup", "postgresql-bdr-cluster::default" ]
    attributes  {
      "postgresql-bdr-cluster" {
        use_interface = "eth0"
      }
    }
  }
  # stop port forwarding
  provisioner "local-exec" {
    command = "./murder.sh"
  }
  instance_type = "c3.xlarge"
  ami = "ami-4dbf9e7d"
  key_name = "${var.user}@postgresql-bdr-cluster"
  subnet_id = "${aws_subnet.postgresql_cluster_subnet.id}"
  security_groups = [ "${aws_security_group.postgresql_cluster_sg.id}" ]
  root_block_device {
    volume_type = "gp2"
    volume_size = 12
  }
  ephemeral_block_device {
    device_name = "/dev/sdb"
    virtual_name = "ephemeral0"
  }
  ephemeral_block_device {
    device_name = "/dev/sdc"
    virtual_name = "ephemeral1"
  }
  tags {
    Name = "postgresql-1.example.com"
    X-Project = "CSE"
  }
}
