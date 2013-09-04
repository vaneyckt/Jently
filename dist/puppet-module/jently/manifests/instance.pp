define jently::instance (
  ensure                   = present,
  github_login             = undef,
  github_password          = undef,
  github_repository        = undef,
  github_polling_interval  = 60,
  jenkins_url              = undef,
  jenkins_login            = undef,
  jenkins_password         = undef,
  jenkins_job_name         = undef,
  jenkins_job_timeout      = 1800,
  jenkins_polling_interval = 60,
  whitelist_branches       = undef,
) {
  include jently

  $config_path = "/etc/jently/${name}.yaml"

  file { $config_path:
    ensure  => present,
    content => template('jently/config.yaml.erb'),
    mode    => '0644',
    owner   => root,
    group   => root,
    require => [
      Class['jently'],
    ],
    notify  => [
      Service["jently-${name}"]
    ]
  }

  if $ensure == present {
    file { "/etc/init/jently-${name}.conf":
      ensure  => present,
      content => template('jently/jently-init.conf.erb'),
      mode    => '0644',
      owner   => root,
      group   => root,
      require => [
        Class['jently'],
        File[$config_path],
      ],
    }

    service { "jently-${name}":
      ensure   => running,
      provider => upstart,
      require  => [
        File["/etc/init/jently-${name}.conf"]
      ]
    }
  }


}
