# Cfnresponse

Cfnresponse helps with writing [Custom CloudFormation resources](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-custom-resources.html). The main method is `send_response`, which builds the response that is sent back to CloudFormation service from the Lambda function.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cfnresponse'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cfnresponse

## Example Usage

```ruby
require "cfnresponse"
include Cfnresponse

def lambda_handler(event:, context:)
  puts("Received event: " + json_pretty(event))

  case event['RequestType']
  when "Create"
    # create logic
    send_response(event, context, "SUCCESS")
  when "Update"
    # update logic
    send_response(event, context, "SUCCESS")
  when "Delete"
    # delete logic
    send_response(event, context, "SUCCESS")
  end

  sleep 10 # a little time for logs to be sent to CloudWatch

# We rescue all exceptions and send a message to CloudFormation so we don't have to
# wait for over an hour for the stack operation to timeout and rollback.
rescue Exception => e
  puts e.message
  puts e.backtrace
  sleep 10 # a little time for logs to be sent to CloudWatch
  send_response(event, context, "FAILED")
end
```

* [Cfnresponse code](lib/cfnresponse.rb)