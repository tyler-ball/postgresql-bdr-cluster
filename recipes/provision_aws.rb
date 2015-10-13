#
# Cookbook Name:: postgresql-bdr-cluster
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

include_recipe 'chef-provisioning-aws-helper::default'

# # Pre-create the machines in parallel
# machine_batch 'precreate' do
#   action [:converge]
#
#   node['postgresql-bdr-cluster']['cluster_nodes'].each do |vmname|
#     machine vmname do
#       recipe 'postgresql-bdr-cluster::aws_instance_setup'
#       machine_options aws_options(vmname)
#     end
#   end
# end

aws_vpc 'postgresql_cluster_vpc' do
  cidr_block '10.0.0.0/16'
  internet_gateway true
  enable_dns_hostnames true
  main_routes '0.0.0.0/0' => :internet_gateway
end

aws_security_group 'postgresql_cluster_sg' do
  vpc 'postgresql_cluster_vpc'
  inbound_rules '0.0.0.0/0' => [ 22, 80 ]
  outbound_rules [ 22, 80 ] => '0.0.0.0/0'
end

aws_subnet 'postgresql_cluster_subnet' do
  vpc 'postgresql_cluster_vpc'
  cidr_block '10.0.0.0/24'
  map_public_ip_on_launch true
  availability_zone (driver.ec2_client.describe_availability_zones.availability_zones.map {|r| r.zone_name}).first
end

# Cannot pass security_groups into aws_options and have it come back out
def get_opts(vmname)
  opts = aws_options(vmname)
  opts[:bootstrap_options][:subnet_id] = 'postgresql_cluster_subnet'
  opts[:bootstrap_options][:security_group_ids] = ['postgresql_cluster_sg']
  opts
end

# do Postgres setup sequentially
node['postgresql-bdr-cluster']['cluster_nodes'].each do |vmname|
  opts = get_opts(vmname)
  machine vmname do
    machine_options opts
    attribute 'postgresql-bdr-cluster', { use_interface: 'eth0' }
    recipe 'postgresql-bdr-cluster::aws_instance_setup'
    recipe 'postgresql-bdr-cluster::default'
    aws_tags 'X-Project' => "CSE"
  end
end
