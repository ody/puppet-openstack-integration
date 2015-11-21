#!/bin/bash

set -ex

if [ ! -z ${GEM_HOME} ]; then
    GEM_BIN_DIR=${GEM_HOME}/bin/
fi

if [ -z ${BASE_PATH} ]; then
    echo 'BASE_PATH not set, assuming legacy paths'
    BASE_PATH='/etc/puppet'
fi

export SCRIPT_DIR=$(cd `dirname $0` && pwd -P)
export PUPPETFILE_DIR=${PUPPETFILE_DIR:-${BASE_PATH}/modules}
source $SCRIPT_DIR/functions

gem install r10k --no-ri --no-rdoc

# There seems like no way to add privatebindir to path from beaker
if [ ${BASE_PATH} = '/etc/puppetlabs/code' ]; then
  ln -s /opt/puppetlabs/puppet/bin/r10k /opt/puppetlabs/bin/r10k
fi

# make sure there is no puppet module pre-installed
rm -rf "${PUPPETFILE_DIR:?}/"*

install_modules

puppet module list

# Hacks to prevent having to patch project-config; should be replaced with a
# more intelligent jenkins/scripts/copy_puppet_logs.sh.
if [ ${BASE_PATH} = '/etc/puppetlabs/code' ]; then
  echo 'Deleting /etc/puppet so we can symlink it'
  rm -rf /etc/puppet
  echo 'Symlinked /etc/puppet to /etc/puppetlabs/code to get around static copy_puppet_logs.sh is project-config'
  ln -s /etc/puppetlabs/code /etc/puppet
fi
