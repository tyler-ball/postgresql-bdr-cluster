task :default => [:up]

desc 'Bring up the Postgres cluster (default)'
task :up => :setup do
  sh('chef-client -z -o postgresql-bdr-cluster::provision')
end

desc 'Provision with terraform'
task :terraup => :setup do
  sh('pkill -f "knife serve"; true') # Kill any existing servers in case they are sitting around
  sh('knife serve &')
  sh("terraform apply -var 'user=#{ENV['USER']}' -var 'client_name=#{ENV['USER']}'")
end

desc 'Destroy the Postgres cluster'
task :destroy do
  sh('chef-client -z -o postgresql-bdr-cluster::destroy')
end
task :cleanup => :destroy

desc 'Destroy the Postgres cluster'
task :terradestroy do
  # kill all the port forwarding processes
  # this should be done via terraform, but having issues getting it to work
  sh('pkill -f ec2-user; true')
  sh("terraform destroy --force -var 'user=#{ENV['USER']}' -var 'client_name=#{ENV['USER']}'")
  sh('pkill -f "knife serve"; true')
end

desc 'Destroy and rebuild each node of the cluster individually'
task :rolling_rebuild => :setup do
  sh('chef-client -z -o postgresql-bdr-cluster::rolling_rebuild')
end

desc 'Chef setup tasks'
task :setup do
  unless Dir.exist?('vendor')
    sh('berks install --quiet')
    Dir.mkdir('vendor')
    sh('berks vendor vendor/ --quiet')
  else
    sh('berks update --quiet')
    sh('rm -rf vendor/*')
    sh('berks vendor vendor/ --quiet')
  end
end
