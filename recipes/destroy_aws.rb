include_recipe 'chef-provisioning-aws-helper::default'

machine_batch do
  action :destroy
  machines search(:node, '*:*').map { |n| n.name }
end

aws_subnet 'postgresql_cluster_subnet' do
  action :destroy
end

aws_security_group 'postgresql_cluster_sg' do
  action :destroy
end

aws_vpc 'postgresql_cluster_vpc' do
  action :destroy
end
