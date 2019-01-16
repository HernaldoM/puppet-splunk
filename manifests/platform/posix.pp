# Class: splunk::platform::posix
#
# This class declares virtual resources and collects existing virtual
# resources for adjustment appropriate to deployment on a Posix host.
# It extends functionality of either splunk, splunk::forwarder, or
# both.
#
# Parameters: none
#
# Actions:
#
#   Declares, tags, and modifies virtual resources realized by other classes
#   in the splunk module.
#
# Requires: nothing
#
class splunk::platform::posix (
  $splunkd_port = undef,
  $splunk_user = $splunk::params::splunk_user,
  $server_service = undef,
  $version = $splunk::params::version,
) inherits splunk::virtual {

  include ::splunk::params
  # Many of the resources declared here are virtual. They will be realized by
  # the appropriate including class if required.


  # Commands to run to enable the SplunkUniversalForwarder
  @exec { 'license_splunkforwarder':
    path    => "${splunk::params::forwarder_dir}/bin",
    command => 'splunk ftr --accept-license --answer-yes --no-prompt',
    user    => $splunk_user,
    onlyif  => "/usr/bin/test -f ${splunk::params::forwarder_dir}/ftr",
    timeout => 0,
    tag     => 'splunk_forwarder',
    notify  => Service['splunk'],
  }

  # If version of splunk >= 7.2.2, then command `splunk enable boot-start` creates systemd service NOT init.d file
  if versioncmp($version, '7.2.2') < 0 {
    $created_file = '/etc/init.d/splunk'
  }
  else {
    $created_file = '/etc/systemd/system/multi-user.target.wants'
  }

  @exec { 'enable_splunkforwarder':
    # The path parameter can't be set because the boot-start silently fails on systemd service providers
    command => "${splunk::params::forwarder_dir}/bin/splunk enable boot-start -user ${splunk_user}",
    creates => "${created_file}/SplunkForwarder.service",
    require => Exec['license_splunkforwarder'],
    tag     => 'splunk_forwarder',
    notify  => Service['splunk'],
  }

  # Commands to run to enable full Splunk
  @exec { 'license_splunk':
    path    => "${splunk::params::server_dir}/bin",
    command => 'splunk start --accept-license --answer-yes --no-prompt',
    user    => $splunk_user,
    creates => '/opt/splunk/etc/auth/splunk.secret',
    timeout => 0,
    tag     => 'splunk_server',
  }
  @exec { 'enable_splunk':
    # The path parameter can't be set because the boot-start silently fails on systemd service providers
    command => "${splunk::params::server_dir}/bin/splunk enable boot-start -user ${splunk_user}",
    creates => "${created_file}/Splunkd.service",
    require => Exec['license_splunk'],
    tag     => 'splunk_server',
    before  => Service['splunk'],
  }

  # Modify virtual service definitions specific to the Linux platform. These
  # are virtual resources declared in the splunk::virtual class, which we
  # inherit.
  if 'splunkd' in $server_service {
    Service['splunkd'] {
      provider => 'base',
      restart  => '/opt/splunk/bin/splunk restart splunkd',
      start    => '/opt/splunk/bin/splunk start splunkd',
      stop     => '/opt/splunk/bin/splunk stop splunkd',
      pattern  => "splunkd -p ${splunkd_port} (restart|start)",
      require  => Service['splunk'],
    }
  }
  if 'splunkweb' in $server_service {
    Service['splunkweb'] {
      provider => 'base',
      restart  => '/opt/splunk/bin/splunk restart splunkweb',
      start    => '/opt/splunk/bin/splunk start splunkweb',
      stop     => '/opt/splunk/bin/splunk stop splunkweb',
      pattern  => 'python -O /opt/splunk/lib/python.*/splunk/.*/root.py.*',
      require  => Service['splunk'],
    }
  }
}
