#
# Copyright 2015 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

case $::osfamily {
  'Debian': {
    $ipv6            = false
    # mistral is not packaged on Ubuntu Trusty
    $mistral_enabled = false
  }
  'RedHat': {
    $ipv6            = true
    # enable when we figure why mistral tempest tests are so unstable
    $mistral_enabled = false
  }
  default: {
    fail("Unsupported osfamily (${::osfamily})")
  }
}

# List of workarounds for Ubuntu Xenial:
# - disable SSL
# - disable Trove (Taskmanager is failing)
if ($::operatingsystem == 'Ubuntu') and (versioncmp($::operatingsystemmajrelease, '16') >= 0) {
  $ssl_enabled     = false
  $trove_enabled   = false
} else {
  $ssl_enabled     = false
  # https://bugs.launchpad.net/trove/+bug/1597857
  $trove_enabled   = false
}

include ::openstack_integration
class { '::openstack_integration::config':
  ipv6 => $ipv6,
  ssl  => $ssl_enabled,
}
include ::openstack_integration::cacert
include ::openstack_integration::memcached
include ::openstack_integration::rabbitmq
include ::openstack_integration::mysql
class { '::openstack_integration::keystone':
  token_provider => 'fernet',
}
include ::openstack_integration::glance
class { '::openstack_integration::neutron':
  driver => 'linuxbridge',
}
include ::openstack_integration::nova
if $trove_enabled {
  include ::openstack_integration::trove
}
include ::openstack_integration::horizon
include ::openstack_integration::heat
# enable when we figure why mistral tempest tests are so unstable
# include ::openstack_integration::mistral
include ::openstack_integration::murano
include ::openstack_integration::sahara
include ::openstack_integration::provision

class { '::openstack_integration::tempest':
  trove   => $trove_enabled,
  sahara  => true,
  mistral => $mistral_enabled,
  horizon => true,
  heat    => true,
  murano  => true,
}
