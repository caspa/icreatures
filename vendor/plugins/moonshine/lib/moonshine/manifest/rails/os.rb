module Moonshine::Manifest::Rails::Os
  # Set up cron and enable the service. You can create cron jobs in your
  # manifests like so:
  #
  #   cron :run_me_at_three
  #     :command => "/usr/sbin/something",
  #     :user => root,
  #     :hour => 3
  #
  #   cron 'rake:task',
  #       :command => "cd #{rails_root} && RAILS_ENV=#{ENV['RAILS_ENV']} rake rake:task",
  #       :user => configuration[:user],
  #       :minute => 15
  def cron_packages
    service "cron", :require => package("cron"), :ensure => :running
    package "cron", :ensure => :installed
  end

  #Overwrites <tt>/etc/motd</tt> to indicate Moonshine Managemnt
  def motd
    exec '/etc/motd',
      :command => 'echo "Moonshine Managed" | tee /etc/motd',
      :unless => "grep 'Moonshine' /etc/motd"
  end

  # Install postfix.
  def postfix
    package 'postfix', :ensure => :latest
  end

  # Install ntp and enables the ntp service.
  def ntp
    package 'ntp', :ensure => :latest
    service 'ntp', :ensure => :running, :require => package('ntp'), :pattern => 'ntpd'
  end

  # Set the system timezone to <tt>configuration[:time_zone]</tt> or 'UTC' by
  # default.
  def time_zone
    zone = configuration[:time_zone] || 'UTC'
    zone = 'UTC' if zone.nil? || zone.strip == ''
    file "/etc/timezone",
      :content => zone+"\n",
      :ensure => :present
    file "/etc/localtime",
      :ensure => "/usr/share/zoneinfo/#{zone}",
      :notify => service('ntp')
  end

private

  #Provides a helper for creating logrotate config for various parts of your
  #stack. For example:
  #
  #  logrotate('/srv/theapp/shared/logs/*.log', {
  #    :options => %w(daily missingok compress delaycompress sharedscripts),
  #    :postrotate => 'touch /srv/theapp/current/tmp/restart.txt'
  #  })
  #
  def logrotate(log_or_glob, options = {})
    options = options.respond_to?(:to_hash) ? options.to_hash : {}

    package "logrotate", :ensure => :installed, :require => package("cron"), :notify => service("cron")

    safename = log_or_glob.gsub(/[^a-zA-Z]/, '')

    file "/etc/logrotate.d/#{safename}.conf",
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), "templates", "logrotate.conf.erb"), binding),
      :notify => service("cron"),
      :alias => "logrotate_#{safename}"
  end

end
