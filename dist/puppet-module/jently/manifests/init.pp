class jently (
  $version  = $jently::params::version,
  $filename = $jently::params::filename,
  $path     = $jently::params::path,
) inherits jently::params {

  file { $path:
    ensure => present,
    source => "puppet:///modules/jently/${filename}",
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
  }

  package { 'jently':
    ensure   => $version,
    source   => $path,
    provider => gem,
    require  => [
      File[$path],
    ],
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
    mode   => '0644',
  }
}
