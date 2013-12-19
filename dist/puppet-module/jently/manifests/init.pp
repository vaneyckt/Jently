class jently (
  $version  = $jently::params::version,
  $filename = $jently::params::filename,
  $path     = $jently::params::path,
) inherits jently::params {

  package { 'jently':
    ensure   => $version,
    provider => gem,
  }

  file { '/etc/jently':
    ensure => directory,
    owner  => root,
    group  => root,
    mode   => '0644',
  }

  file { '/var/log/jently':
    ensure => directory,
    owner  => daemon,
    group  => daemon,
    mode   => '0755',
  }

  file { '/var/lib/jently':
    ensure => directory,
    owner  => daemon,
    group  => daemon,
    mode   => '0755',
  }
}
