# The following part downloads and installs the chosen ruby version
#
define rbenv::download(
  $user,
  $ruby           = $title,
  $group          = $user,
  $home           = '',
  $root           = '',
  $url            = '',
  $global         = false,
  $bundler        = present,
) {

  $home_path = $home ? { '' => "/home/${user}", default => $home }
  $root_path = $root ? { '' => "${home_path}/.rbenv", default => $root }

  $bin         = "${root_path}/bin"
  $shims       = "${root_path}/shims"
  $versions    = "${root_path}/versions"
  $global_path = "${root_path}/version"
  $path        = [ $shims, $bin, '/bin', '/usr/bin' ]

  if ! defined( Class['rbenv::dependencies'] ) {
    require rbenv::dependencies
  }

  $mkdir_cmd = "mkdir ${versions}/${ruby}"
  $download_cmd = "curl -L ${url} -o /tmp/${ruby}"
  $untar_cmd = "tar xf /tmp/${ruby} -C ${versions}/${ruby}"
  $clean_cmd = "rm /tmp/${ruby}"

  # Use HOME variable and define PATH correctly.
  exec { "rbenv::download ${user} ${ruby}":
    command     => "${mkdir_cmd} && ${download_cmd} && ${untar_cmd} && touch ${root_path}/.rehash; ${clean_cmd}",
    timeout     => 0,
    user        => $user,
    group       => $group,
    cwd         => $home_path,
    environment => [ "HOME=${home_path}" ],
    creates     => "${versions}/${ruby}/bin",
    path        => $path,
    logoutput   => 'on_failure',
    require     => Package["wget"],
    before      => Exec["rbenv::rehash ${user} ${ruby}"],
  }

  exec { "rbenv::rehash ${user} ${ruby}":
    command     => "rbenv rehash && rm -f ${root_path}/.rehash",
    user        => $user,
    group       => $group,
    cwd         => $home_path,
    onlyif      => "[ -e '${root_path}/.rehash' ]",
    environment => [ "HOME=${home_path}" ],
    path        => $path,
    logoutput   => 'on_failure',
  }

  # Install bundler
  #
  rbenv::gem {"rbenv::bundler ${user} ${ruby}":
    ensure => $bundler,
    user   => $user,
    ruby   => $ruby,
    gem    => 'bundler',
    home   => $home_path,
    root   => $root_path,
  }

  # Set default global ruby version for rbenv, if requested
  #
  if $global {
    file { "rbenv::global ${user}":
      path    => $global_path,
      content => "${ruby}\n",
      owner   => $user,
      group   => $group,
      require => Exec["rbenv::compile ${user} ${ruby}"]
    }
  }
}
