##
#
class openstack_integration::murano {

  include ::openstack_integration::config
  include ::openstack_integration::params

  rabbitmq_vhost { '/murano':
    provider => 'rabbitmqctl',
    require  => Class['rabbitmq'],
  }
  rabbitmq_user { 'murano':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['rabbitmq'],
  }
  rabbitmq_user_permissions { 'murano@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['rabbitmq'],
  }
  rabbitmq_user_permissions { 'murano@/murano':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['rabbitmq'],
  }

  class { '::murano::db::mysql': password => 'murano' }
  class { '::murano::api': host => $::openstack_integration::config::host }
  class { '::murano::engine': }
  class { '::murano::keystone::auth':
    password     => 'a_big_secret',
    public_url   => "${::openstack_integration::config::base_url}:8082",
    internal_url => "${::openstack_integration::config::base_url}:8082",
    admin_url    => "${::openstack_integration::config::base_url}:8082",
  }

  class { '::murano':
    admin_password      => 'a_big_secret',
    rabbit_os_user      => 'murano',
    rabbit_os_password  => 'an_even_bigger_secret',
    rabbit_os_use_ssl   => $::openstack_integration::config::ssl,
    rabbit_os_port      => $::openstack_integration::config::rabbit_port,
    rabbit_os_host      => $::openstack_integration::config::ip_for_url,
    rabbit_own_user     => 'murano',
    rabbit_own_password => 'an_even_bigger_secret',
    rabbit_own_vhost    => '/murano',
    rabbit_own_port     => $::openstack_integration::config::rabbit_port,
    rabbit_own_host     => $::openstack_integration::config::ip_for_url,
    database_connection => 'mysql+pymysql://murano:murano@127.0.0.1/murano?charset=utf8',
    auth_uri            => $::openstack_integration::config::keystone_auth_uri,
    identity_uri        => $::openstack_integration::config::keystone_admin_uri,
    debug               => true,
  }
}

