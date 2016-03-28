# Configure the Keystone service
#
# [*default_domain*]
#   (optional) Define the default domain id.
#   Set to 'undef' for 'Default' domain.
#   Default to undef.
#
# [*using_domain_config*]
#   (optional) Eases the use of the keystone_domain_config resource type.
#   It ensures that a directory for holding the domain configuration is present
#   and the associated configuration in keystone.conf is set up right.
#   Defaults to false
#
class openstack_integration::keystone (
  $default_domain      = undef,
  $using_domain_config = false,
) {

  include ::openstack_integration::config
  include ::openstack_integration::params

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'keystone':
      notify  => Service['httpd'],
      require => Package['keystone'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  class { '::keystone::client': }
  class { '::keystone::cron::token_flush': }
  class { '::keystone::db::mysql':
    password => 'keystone',
  }
  class { '::keystone':
    verbose             => true,
    debug               => true,
    database_connection => 'mysql+pymysql://keystone:keystone@127.0.0.1/keystone',
    admin_token         => 'admin_token',
    enabled             => true,
    service_name        => 'httpd',
    default_domain      => $default_domain,
    using_domain_config => $using_domain_config,
    enable_ssl          => $::openstack_integration::config::ssl,
  }
  include ::apache
  class { '::keystone::wsgi::apache':
    ssl      => $::openstack_integration::config::ssl,
    ssl_key  => "/etc/keystone/ssl/private/${::fqdn}.pem",
    ssl_cert => $::openstack_integration::params::cert_path,
    workers  => 2,
  }
  class { '::keystone::roles::admin':
    email    => 'test@example.tld',
    password => 'a_big_secret',
  }
  class { '::keystone::endpoint':
    default_domain => $default_domain,
    public_url     => $::openstack_integration::config::keystone_auth_uri,
    admin_url      => $::openstack_integration::config::keystone_admin_uri,
  }

  class { '::openstack_extras::auth_file':
    password       => 'a_big_secret',
    project_domain => 'default',
    user_domain    => 'default',
    auth_url       => "${::openstack_integration::config::keystone_auth_uri}/v3/",
  }

  include ::keystone::disable_admin_token_auth
  Keystone::Resource::Service_identity<||> -> Class['::openstack_extras::auth_file'] -> Class['::keystone::disable_admin_token_auth']
}
