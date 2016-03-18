#!/bin/bash -ex
# Copyright 2015 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

export PUPPET_VERSION=$(PUPPET_VERSION:-3)
export SCENARIO=${SCENARIO:-scenario001}
export MANAGE_PUPPET_MODULES=${MANAGE_PUPPET_MODULES:-true}
export MANAGE_REPOS=${MANAGE_REPOS:-true}
export PUPPET_ARGS=${PUPPET_ARGS:-}
export SCRIPT_DIR=$(cd `dirname $0` && pwd -P)

if [ $PUPPET_VERSION == 4 ]; then
  export PATH=${PATH}:/opt/puppetlabs/bin
  export RELEASE_FILE=puppetlabs-release-pc1
  export BASE=/etc/puppetlabs/code
else
  export RELEASE_FILE=puppetlabs-release
  export BASE=/etc/puppet
fi

source ${SCRIPT_DIR}/functions

if [ ! -f fixtures/${SCENARIO}.pp ]; then
    echo "fixtures/${SCENARIO}.pp file does not exist. Please define a valid scenario."
    exit 1
fi

if [ $(id -u) != 0 ]; then
  # preserve environment so we can have ZUUL_* params
  SUDO='sudo -E'
fi

# TODO(pabelanger): Move this into tools/install_tempest.sh and add logic so we
# can clone tempest outside of the gate. Also, tempest should be sandboxed into
# the local directory but works needs to be added into puppet to properly find
# the path.
if [ -e /usr/zuul-env/bin/zuul-cloner ] ; then
    /usr/zuul-env/bin/zuul-cloner --workspace /tmp --cache-dir /opt/git \
        git://git.openstack.org openstack/tempest
else
    # remove existed checkout before clone
    $SUDO rm -rf /tmp/openstack/tempest

    # We're outside the gate, just do a regular git clone
    git clone git://git.openstack.org/openstack/tempest /tmp/openstack/tempest
fi

PUPPET_ARGS="${PUPPET_ARGS} --detailed-exitcodes --verbose --color=false --debug"

function run_puppet() {
    local manifest=$1
    $SUDO puppet apply $PUPPET_ARGS fixtures/${manifest}.pp
    local res=$?

    return $res
}

if uses_debs; then
    if dpkg -l $RELEASE_FILE >/dev/null 2>&1; then
        $SUDO apt-get purge -y $RELESE_FILE
    fi
    $SUDO rm -f /tmp/puppet.deb

    wget http://apt.puppetlabs.com/${RELEASE_FILE}-trusty.deb -O /tmp/puppet.deb
    $SUDO dpkg -i /tmp/puppet.deb
    $SUDO apt-get update
    $SUDO apt-get install -y dstat puppet-agent
elif is_fedora; then
    if rpm --quiet -q $RELEASE_FILE; then
        $SUDO rpm -e $RELEASE_FILE
    fi
    $SUDO rm -f /tmp/puppet.rpm

    wget  http://yum.puppetlabs.com/${RELEASE_FILE}-el-7.noarch.rpm -O /tmp/puppet.rpm
    $SUDO rpm -ivh /tmp/puppet.rpm
    $SUDO yum install -y dstat puppet-agent
fi

# use dstat to monitor system activity during integration testing
if type "dstat" 2>/dev/null; then
  $SUDO dstat -tcmndrylpg --top-cpu-adv --top-io-adv --nocolor | $SUDO tee --append /var/log/dstat.log > /dev/null &
fi

if [ "${MANAGE_PUPPET_MODULES}" = true ]; then
    $SUDO ./install_modules.sh
fi

# Run puppet and assert something changes.
set +e
if [ "${MANAGE_REPOS}" = true ]; then
  $SUDO puppet apply $PUPPET_ARGS -e "include ::openstack_integration::repos"
fi
run_puppet $SCENARIO
RESULT=$?
set -e
if [ $RESULT -ne 2 ]; then
    exit 1
fi

# Run puppet a second time and assert nothing changes.
set +e
run_puppet $SCENARIO
RESULT=$?
set -e
if [ $RESULT -ne 0 ]; then
    exit 1
fi

mkdir -p /tmp/openstack/tempest

$SUDO rm -f /tmp/openstack/tempest/cirros-0.3.4-x86_64-disk.img

# TODO(emilien) later, we should use local image if present. That would be a next iteration.
wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img -P /tmp/openstack/tempest

set +e
# Select what to test:
# Smoke suite
TESTS="smoke"

# Horizon
TESTS="${TESTS} dashbboard"

# Aodh
TESTS="${TESTS} TelemetryAlarming"

# Ironic
# Note: running all Ironic tests under SSL is not working
# https://bugs.launchpad.net/ironic/+bug/1554237
TESTS="${TESTS} api.baremetal.admin.test_drivers"

cd /tmp/openstack/tempest; tox -eall -- --concurrency=2 $TESTS
RESULT=$?
set -e
/tmp/openstack/tempest/.tox/all/bin/testr last --subunit > /tmp/openstack/tempest/testrepository.subunit
exit $RESULT
