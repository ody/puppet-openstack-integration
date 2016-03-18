##
#
class openstack_integration::ironic {

  include ::openstack_integration::config
  include ::openstack_integration::params

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'ironic':
      notify  => Service['httpd'],
      require => Package['ironic-common'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  rabbitmq_user { 'ironic':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'ironic@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  class { '::ironic':
    rabbit_userid       => 'ironic',
    rabbit_password     => 'an_even_bigger_secret',
    rabbit_host         => $::openstack_integration::config::rabbit_host,
    rabbit_port         => $::openstack_integration::config::rabbit_port,
    rabbit_use_ssl      => $::openstack_integration::config::ssl,
    database_connection => 'mysql+pymysql://ironic:ironic@127.0.0.1/ironic?charset=utf8',
    debug               => true,
    verbose             => true,
    enabled_drivers     => ['fake', 'pxe_ssh', 'pxe_ipmitool'],
  }
  class { '::ironic::db::mysql':
    password      => 'ironic',
    allowed_hosts => ['localhost'],
  }
  class { '::ironic::keystone::auth':
    public_url   => "${::openstack_integration::config::proto}://127.0.0.1:6385",
    internal_url => "${::openstack_integration::config::proto}://127.0.0.1:6385",
    admin_url    => "${::openstack_integration::config::proto}://127.0.0.1:6385",
    password     => 'a_big_secret',
  }
  class { '::ironic::client': }
  class { '::ironic::api':
    auth_uri       => $::openstack_integration::config::keystone_auth_uri,
    identity_uri   => $::openstack_integration::config::keystone_admin_uri,
    neutron_url    => 'http://127.0.0.1:9696',
    admin_password => 'a_big_secret',
    service_name   => 'httpd',
  }
  include ::apache
  class { '::ironic::wsgi::apache':
    ssl      => $::openstack_integration::config::ssl,
    ssl_key  => "/etc/ironic/ssl/private/${::fqdn}.pem",
    ssl_cert => $::openstack_integration::params::cert_path,
    workers  => 2,
  }
  class { '::ironic::conductor': }
  Rabbitmq_user_permissions['ironic@/'] -> Service<| tag == 'ironic-service' |>

}
