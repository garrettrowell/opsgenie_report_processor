# opsgenie_report_processor

## Table of Contents

1. [Description](#description)
1. [Setup](#setup)
1. [Testing Functionality](#testing-functionality)

## Pre-reqs

* Puppet Enterprise or Open Source Puppet.
* An [Opsgenie](https://www.atlassian.com/software/opsgenie) account.

## Description

A Puppet report processor that creates an alert in Opsgenie if an agent fails a puppet run.
On successful agent runs, Opsgenie is checked for an open Alert. If an alert is found, it is gets closed.

## Setup

### Basic Install and configuration

Add the module to the Puppetfile and deploy the code and configure the Opsgenie api key.

```puppet
class { 'opsgenie_report_processor':
  api_key => '########################',
}
```

### Configure URI

The default configuration pints to ```https://api.opsgenie.com/v2/alerts```, however in Europe a different endpoint must be specified.

```puppet
class { 'opsgenie_report_processor':
  api_key => '########################',
  api_uri => 'https://api.eu.opsgenie.com/v2'
}
```

### Configure the alert levels

By default all alerts will be severity P3, however different alert levels can be configured for production and non-production. Available alert levels are P1, P2, P3 and P4. 

```puppet
class { 'opsgenie_report_processor':
  api_key                    => '########################',
  api_uri                    => 'https://api.eu.opsgenie.com/v2'
  production_alert_level     => 'P1',
  non_production_alert_level => 'P2',
}
```

## Testing Functionality

One way to test this report processor is by adding the following Puppet code to some node(s)

```puppet
if $facts['fail_catalog'] == 'true' {
  fail('i was told to fail...')
}
```

Then when you want a catalog to fail simply create `/etc/puppetlabs/facter/facts.d/fail_catalog.txt` with the following content:

```txt
fail_catalog=true
```

And when you want a successful run:

```txt
fail_catalog=false
```
