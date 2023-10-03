# @summary A class to manage OpsGenie integration
#
# A description of what this class does
#
# @example
#   class { 'opsgenie_report_processor'
#      api_key => '###################',
#   }
# @param [String] api_key
#   The API key used to access the OpsGenie account, this must be set.
# @param [String] api_uri
#   The API URI, the default is https://api.opsgenie.com/v2/alerts
#   But within Europe it will need to be overridden by https://api.eu.opsgenie.com/v2/alerts
# @param [Enum[p1, P2, P3, P4]] production_alert_level
#   The alert level for alerts from the production environment, if unset default is P3
# @param [Enum[p1, P2, P3, P4] non_production_alert_level
#   The alert level for alerts all other environments, if unset default is P3

class opsgenie_report_processor (
  String[1]                      $api_key,
  Optional[String]               $api_uri                     = undef,
  Optional[Enum['P1', 'P2', 'P3', 'P4']] $production_alert_level      = undef,
  Optional[Enum['P1', 'P2', 'P3', 'P4']] $non_production_alert_level  = undef,
) {
  file { '/etc/puppetlabs/puppet/opsgenie.yaml':
    ensure  => file,
    owner   => 'pe-puppet',
    group   => 'pe-puppet',
    mode    => '0640',
    content => epp('opsgenie_report_processor/opsgenie.yaml.epp', {
        api_key                    => $api_key,
        api_uri                    => $api_uri,
        production_alert_level     => $production_alert_level,
        non_production_alert_level => $non_production_alert_level,
    }),
    notify  => Service['pe-puppetserver'],
  }

  ini_subsetting { 'puppetserver puppetconf add opsgenie report processor':
    ensure               => present,
    path                 => $settings::config,
    section              => 'master',
    setting              => 'reports',
    subsetting           => 'opsgenie',
    subsetting_separator => ',',
    notify               => Service['pe-puppetserver'],
    require              => File['/etc/puppetlabs/puppet/opsgenie.yaml'],
  }
}
