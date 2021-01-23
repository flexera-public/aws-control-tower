require "cfnresponse/version"
require "json"
require "net/http"
require "uri"

module Cfnresponse
  class Error < StandardError; end

  # Debugging puts kept to help debug custom resources
  def send_response(event, context, response_status, response_data={}, physical_id="PhysicalId", reason=nil)
    reason ||= "See the details in CloudWatch Log Group: #{context.log_group_name} Log Stream: #{context.log_stream_name}"

    body_data = {
      "Status" => response_status,
      "Reason" => reason,
      "PhysicalResourceId" => physical_id,
      "StackId" => event['StackId'],
      "RequestId" => event['RequestId'],
      "LogicalResourceId" => event['LogicalResourceId'],
      "Data" => response_data
    }

    puts "Response body:\n"
    puts json_pretty(body_data)

    response_body = JSON.dump(body_data) # response_body is a JSON string

    url = event['ResponseURL']
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = http.read_timeout = 30
    http.use_ssl = true if uri.scheme == 'https'

    # must used url to include the AWSAccessKeyId and Signature
    req = Net::HTTP::Put.new(url) # url includes query string and uri.path does not, must used url t
    req.body = response_body
    req.content_length = response_body.bytesize

    # set headers
    req['content-type'] = ''
    req['content-length'] = response_body.bytesize

    if ENV['CFNRESPONSE_TEST']
      puts "uri #{uri.inspect}"
      return body_data # early return to not send the request
    end

    res = http.request(req)
    puts "status code: #{res.code}"
    puts "headers: #{res.each_header.to_h.inspect}"
    puts "body: #{res.body}"
  end

  # Useful for pretty json output on cloud9 and also CloudWatch logs
  def json_pretty(data)
    if ENV['C9_USER']
      JSON.pretty_generate(data)
    else
      JSON.dump(data) # one a single line for CloudWatch to reformat
    end
  end
end
