/*
  Instructions for running comparison:

  You need to run the chef-provisioning recipe first because that sets up the
  local cookbook repo for chef-zero to host and the SSH key for the instances.

  # Chef Provisioning
  1) Install the ChefDK
  2) Ensure your `~/.aws/credentials` file is populated with your credentials (either in the [default] or a named profile)
  3) run `AWS_DEFAULT_PROFILE=foo rake up` from within this repo.  You only need to set the env variable if you are using a non-default profile.
  4) check us-west-2 in the console - you should see everything running!
    1) Note - there is a bug in the provisioning cookbook right now where the postgres nodes cannot find each other
  5) run `AWS_DEFAULT_PROFILE=foo rake destroy` to destroy it.
  6) check `./nodes` and make sure it is empty - otherwise this will mess up chef search

  # Terraform
  1) run `AWS_ACCESS_KEY_ID=foo AWS_SECRET_ACCESS_KEY=bar rake terraup` from within this repo.  There is an open TF bug for supporting profiles in ~/.aws/credentials.
    a) Modify the Rakefile if you want to change the user or client_name
    b) This also depends on the key having been created by chef-provisioning - terraform doesn't have a way to create custom keys, only upload them
  2) run `AWS_ACCESS_KEY_ID=foo AWS_SECRET_ACCESS_KEY=bar rake terradestroy` to clean the instances up
*/

provider "aws" {
    region = "us-west-2"
}

# Modify the RAKEFILE for how you want to set these
variable "user" {}

variable "client_name" {}

resource "aws_vpc" "postgresql_cluster_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags {
    X-Project = "CSE"
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
      X-Project = "CSE"
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
      from_port = 0
      to_port = 0
      protocol = "-1"
      self = true
  }
  egress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
      from_port = 443
      to_port = 443
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      self = true
  }
  tags {
    X-Project = "CSE"
  }
}

resource "aws_subnet" "postgresql_cluster_subnet" {
    vpc_id = "${aws_vpc.postgresql_cluster_vpc.id}"
    cidr_block = "10.0.0.0/24"
    map_public_ip_on_launch = true
    tags {
      X-Project = "CSE"
    }
}

resource "aws_route_table_association" "postgresql_cluster_public_routing" {
    subnet_id = "${aws_subnet.postgresql_cluster_subnet.id}"
    route_table_id = "${aws_route_table.r.id}"
}

resource "aws_instance" "postgresql" {
  count = 3
  connection {
    user = "ec2-user"
    key_file = ".chef/keys/${var.user}@postgresql-bdr-cluster"
  }
  # Make sure the remote node is connectable
  # Drop the ohai hints file so it populates automatic attributes
  provisioner "remote-exec" {
    inline = "sudo mkdir -p /etc/chef/ohai/hints/ && sudo touch /etc/chef/ohai/hints/ec2.json"
  }
  # Forward 8889 to the remote host
  provisioner "local-exec" {
    command = "./forward.sh ${var.user} ${self.public_ip}"
  }
  provisioner "chef" {
    server_url = "http://localhost:8889"
    validation_client_name = "${var.client_name}"
    validation_key_path = "~/.chef/${var.client_name}.pem"
    node_name = "postgresql-${count.index}.example.com"
    run_list = [ "postgresql-bdr-cluster::aws_instance_setup", "postgresql-bdr-cluster::default" ]
    attributes  {
      "postgresql-bdr-cluster" {
        use_interface = "eth0"
      }
    }
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
    Name = "postgresql-${count.index}.example.com"
    X-Project = "CSE"
  }
}
