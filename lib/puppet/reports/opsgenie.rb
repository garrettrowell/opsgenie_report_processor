require 'puppet'
require 'net/https'
require 'uri'
require 'json'
require 'yaml'
require 'erb'

Puppet::Reports.register_report(:opsgenie) do
  desc 'Open an Opsgenie Alert on failed puppet runs'

  configfile = File.join([File.dirname(Puppet.settings[:config]), 'opsgenie.yaml'])
  raise(Puppet::ParseError, "Opsgenie report config file #{configfile} not readable") unless File.exist?(configfile)
  begin
    config = YAML.load_file(configfile)
  rescue TypeError => e
    raise Puppet::ParseError, "Opsgenie Yaml file is invalid. #{e.message}"
  end

  API_KEY = config['api_key'] || nil
  API_BASE_URI = config['api_uri'] || 'https://api.opsgenie.com/v2/alerts'

  raise(Puppet::Error, "api_key must be set in #{configfile}") if API_KEY.nil?

  # authentication header
  Header = {
    'Content-Type'  => 'application/json',
    'Authorization' => "GenieKey #{API_KEY}"
  }

  def post(api_uri: API_BASE_URI, header: Header, data: {})
    uri = URI.parse(api_uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.request_uri, header)
    request.body = data.to_json
    response = http.request(request)
    case response
    when Net::HTTPSuccess
      Puppet.info("POST request to #{api_uri} successful")
      return response
    else
      raise(Puppet::Error, "Unable to make POST request to #{api_uri} #{response.code} #{response.message} #{response.body}")
    end
  end

  def get(api_uri: API_BASE_URI, header: Header, data: {})
    uri = URI.parse(api_uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri, header)
    request.body = data.to_json unless data.empty?
    response = http.request(request)
    case response
    when Net::HTTPSuccess
      Puppet.info("GET request to #{api_uri} successful")
      return response
    else
      # get_alert returns 404 when no alert is found
      if response.code == '404'
        response_body = JSON.parse(response.body)
        Puppet.info(response_body['message'])
        return response
      else
        raise(Puppet::Error, "Unable to make GET request to #{api_uri} #{response.code} #{response.message} #{response.body}")
      end
    end
  end

  def create_alert(identifier)
    # https://docs.opsgenie.com/docs/alert-api#create-alert

    Puppet.info("Creating Opsgenie alert for '#{identifier}'")

    alert_data = {
      'message' => "Puppet run for #{self.host} Failed at #{self.time}",
      'alias'   => identifier,
    }

    self.post(data: alert_data)
  end

  def get_alert(identifier)
    # https://docs.opsgenie.com/docs/alert-api#get-alert

    Puppet.info("Checking Opsgenie alerts for '#{identifier}'")
    encoded_identifier = ERB::Util.url_encode(identifier)

    self.get(api_uri: "#{API_BASE_URI}/#{encoded_identifier}?identifierType=alias")
  end

  def close_alert(identifier)
    # https://docs.opsgenie.com/docs/alert-api#close-alert

    Puppet.info("Closing Opsgenie alert for '#{identifier}'")
    encoded_identifier = ERB::Util.url_encode(identifier)

    close_data = {
      'note' => "Puppet run for #{self.host} Succeeded at #{self.time}"
    }

    self.post(api_uri: "#{API_BASE_URI}/#{encoded_identifier}/close?identifierType=alias", data: close_data)
  end

  def process
    identifier = "#{self.host} failed_puppetrun"

    self.status != nil ? status = self.status : status = 'undefined'

    # If node fails open an alert
    if status == 'failed' or status == 'undefined' then

      create_alert_response = self.create_alert(identifier)

    # If the node is successful:
    #  - First check if there is an open alert for the given node.
    #  - If there is an open alert, close it.
    elsif status == 'changed' or status == 'unchanged'
      get_alert_response = self.get_alert(identifier)

      case get_alert_response
      when Net::HTTPSuccess
        response_body = JSON.parse(get_alert_response.body)
        # Check if there is an open alert for said node
        if response_body['data']['status'] == 'open'
          Puppet.info("Found open Opsgenie alert for '#{identifier}'")
          # Since we found an open alert close it
          close_alert_response = self.close_alert(identifier)
        end
      end
    end
  end
end
