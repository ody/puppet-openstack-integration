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

# Setup all our class declarations with defaults that are needed to bring up
# a basic cloud.
include ::openstack_integration
include ::openstack_integration::rabbitmq
include ::openstack_integration::mysql
include ::openstack_integration::keystone
include ::openstack_integration::glance
include ::openstack_integration::neutron
include ::openstack_integration::nova
include ::openstack_integration::cinder
include ::openstack_integration::horizon
include ::openstack_integration::keystone::secure
include ::openstack_integration::provision

# Bring in the tempest module so we can validate that the cloud works
# successfully as expected.
class { '::openstack_integration::tempest':
  horizon => true,
  cinder  => true,
}

# Now we explicitly setup all our class dependencies so everything runs in a
# very specific order, the basics, message queue, database, then keystone so
# we know everything else will have all the bootstrapped bits around so that
# they finish setup properly, finally we secure keystone and provision some
# resources for tempest to leverage,
Class['::openstack_integration'] ->
Class[[
  '::openstack_integration::rabbitmq',
  '::openstack_integration::mysql'
]] ->
Class['::openstack_integration::keystone'] ->
Class[[
  '::openstack_integration::glance',
  '::openstack_integration::neutron',
  '::openstack_integration::nova',
  '::openstack_integration::cinder',
  '::openstack_integration::horizon',
  '::openstack_integration::tempest'
]] ->
Class['::openstack_integration::provision'] ->
Class['::openstack_integration::keystone::secure'] ->
