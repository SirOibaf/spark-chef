Chef::Recipe.send(:include, Hops::Helpers)

eventlog_dir = "#{node['hops']['hdfs']['user_home']}/#{node['hadoop_spark']['user']}/applicationHistory"
tmp_dirs   = ["#{node['hops']['hdfs']['user_home']}/#{node['hadoop_spark']['user']}", eventlog_dir ]
for d in tmp_dirs
 hops_hdfs_directory d do
    action :create_as_superuser
    owner node['hadoop_spark']['user']
    group node['hadoop_spark']['group']
    mode "1777"
  end
end

deps = ""
if exists_local("hops", "nn") 
  deps = "namenode.service"
end  
service_name="sparkhistoryserver"

service service_name do
  provider Chef::Provider::Service::Systemd
  supports :restart => true, :stop => true, :start => true, :status => true
  action :nothing
end

case node['platform_family']
when "rhel"
  systemd_script = "/usr/lib/systemd/system/#{service_name}.service"
else
  systemd_script = "/lib/systemd/system/#{service_name}.service"
end

template systemd_script do
  source "#{service_name}.service.erb"
  owner "root"
  group "root"
  mode 0754
  variables({
              :deps => deps
            })
  if node["services"]["enabled"] == "true"
    notifies :enable, resources(:service => service_name)
  end
  notifies :start, resources(:service => service_name), :immediately
end

kagent_config service_name do
  action :systemd_reload
end


if node['kagent']['enabled'] == "true"
   kagent_config service_name do
     service "HISTORY_SERVERS"
     log_file "#{node['hadoop_spark']['base_dir']}/logs/spark-#{node['hadoop_spark']['user']}-org.apache.spark.deploy.history.HistoryServer-1-#{node['hostname']}.out"
   end
end

if service_discovery_enabled()
  # Register historyserver with Consul
  consul_service "Registering historyserver with Consul" do
    service_definition "historyserver-consul.hcl.erb"
    action :register
  end
end