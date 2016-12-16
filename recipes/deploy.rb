#
# Copyright:: Copyright (c) 2015 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# We need the Train gem available to use

chef_gem 'train' do
  compile_time true
end

require 'train'

secrets = get_project_secrets

# Send CCR requests to every node that is running this cookbook or any
# other one in the current project
search_terms = []
get_all_project_cookbooks.each do |cookbook|
  search_terms << "recipes:#{cookbook.name}*"
end

unless search_terms.empty?
  search_query = "(#{search_terms.join(' OR ')}) " \
                 "AND chef_environment:#{delivery_environment} " \
                 "AND #{deployment_search_query}"

  my_nodes = delivery_chef_server_search(:node, search_query.to_s)
  cache = delivery_workspace_cache

  my_nodes.each do |i_node|
    case i_node['os']
    when 'linux'
      # do linux stuff
      ssh_user = secrets['delivery_infra']['user']
      ssh_private_key_file = "#{cache}/.ssh/#{secrets['delivery_infra']['user']}.pem"
      ip_address = i_node['ipaddress']
      directory "#{cache}/.ssh" do
        recursive true
        action :create
      end
      file ssh_private_key_file do
        content secrets['delivery_infra']['ssh-private-key']
        sensitive true
        mode '0600'
      end
      ruby_block 'run-chef-client' do
        block do
          train = Train.create('ssh', host: ip_address, port: 22, user: ssh_user, key_files: ssh_private_key_file, pty: true)
          conn = train.connection.run_command('sudo /usr/bin/chef-client')
          puts conn.stdout
          raise "Error" if conn.exit_status != 0
        end
        notifies :delete, "file[#{ssh_private_key_file}]", :delayed
      end

    when 'windows'
      # do windows stuff
    end

  end
end
