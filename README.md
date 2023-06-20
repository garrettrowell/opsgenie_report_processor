# opsgenie_report_processor

## Table of Contents

1. [Description](#description)
1. [Setup](#setup)
1. [Testing Functionality](#testing-functionality)

## Description

A Puppet report processor that creates an alert in Opsgenie if an agent fails a puppet run.
On successful agent runs, Opsgenie is checked for an open Alert. If an alert is found, it is gets closed.

## Setup

1. Add this module to your Puppetfile and deploy the code.
1. On your primary puppet server create `/etc/puppetlabs/puppet/opsgenie.yaml` with the following content (using your own api key):
    ```yaml
    api_key: '9r2ku2yc-it85-q4oa-hf22-ahahiq4mphes'
    ```
1. On your primary puppet server modify `/etc/puppetlabs/puppet/puppet.conf` so that the `reports` setting includes `opsgenie`. For example:
    ```yaml
    [master]
    reports = puppetdb,opsgenie
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
