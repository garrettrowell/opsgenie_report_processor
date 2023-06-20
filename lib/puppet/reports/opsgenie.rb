require 'puppet'
require 'net/https'
require 'uri'
require 'json'
require 'yaml'
require 'erb'

Puppet::Reports.register_report(:opsgenie) do
  configfile = File.join([File.dirname(Puppet.settings[:config]), 'opsgenie.yaml'])
  reaise(Puppet::ParseError, "OpsGenie report config file #{configfile} not readable") unless File.exist?(configfile)
  begin
    config = YAML.load_file(configfile)
  rescue TypeError => e
    raise Puppet::ParseError, "OpsGenie Yaml file is invalid. #{e.message}"
  end

  API_KEY = config['api_key'] || nil
  API_BASE_URI = config['api_uri'] || 'https://api.opsgenie.com/v2/alerts'

  desc <<-DESC
  Send notification of failed reports to OpsGenie
  DESC

  def process
    identifier = "#{self.host} failed_puppetrun"

    self.status != nil ? status = self.status : status = 'undefined'
    Puppet.info(status)

    # If node fails open an alert
    if status == 'failed' or status == 'undefined' then
      uri = URI.parse(API_BASE_URI)

      header = {
        'Content-Type'  => 'application/json',
        'Authorization' => "GenieKey #{API_KEY}"
      }

      data = {
        'message' => "Puppet run for #{self.host} #{status} at #{Time.now.asctime}",
        'alias'   => identifier,
      }

      # Create HTTP Objects
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri.request_uri, header)
      request.body = data.to_json

      # Send the request
      response = http.request(request)
      # Todo: response error handling
      Puppet.info(response.inspect)

    # If the node is successful:
    #  - First check if there is an open alert for the given node.
    #  - If there is an open alert, close it.
    elsif status == 'changed' or status == 'unchanged'
      node_alias = ERB::Util.url_encode(identifier)
      uri = URI.parse("#{API_BASE_URI}/#{node_alias}?identifierType=alias")

      header = {
        'Content-Type'  => 'application/json',
        'Authorization' => "GenieKey #{API_KEY}"
      }

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri, header)

      # Send the request
      response = http.request(request)

      case response
        when Net::HTTPSuccess
          response_body = JSON.parse(response.body)
          # Check if there is an open alert for said node
          if response_body['data']['status'] == 'open'
            Puppet.info("Alert open for #{self.host}")
            # Now that our node is healty close the alert
            uri = URI.parse("#{API_BASE_URI}/#{node_alias}/close?identifierType=alias")

            header = {
              'Content-Type'  => 'application/json',
              'Authorization' => "GenieKey #{API_KEY}"
            }

            data = {
              'note' => "Puppet run for #{self.host} #{status} at #{Time.now.asctime}"
            }

            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            request = Net::HTTP::Post.new(uri.request_uri, header)
            request.body = data.to_json

            # Send the request
            response = http.request(request)
            # Todo: response error handling
            Puppet.info(response.body)

          else
            Puppet.info("No alert currently for #{self.host}")
          end
        else
          # Todo: response error handling
          Puppet.info(response.body)
      end
    end
  end
end
