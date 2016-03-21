# Secure Keystone after setup
#
class openstack_integration::keystone::secure {

  include ::openstack_integration::config

  contain ::keystone::disable_admin_token_auth

  class { '::openstack_extras::auth_file':
    password       => 'a_big_secret',
    project_domain => 'default',
    user_domain    => 'default',
    auth_url       => "${::openstack_integration::config::keystone_auth_uri}/v3/",
  }
  contain ::openstack_extras::auth_file
}
