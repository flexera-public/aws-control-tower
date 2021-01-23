require 'aws-sdk'
require 'securerandom'
require 'json'
require "cfnresponse"
include Cfnresponse

def lambda_handler(event:, context:)
  puts("Received event: " + json_pretty(event))

  case event['RequestType']
  when "Create"
    region = ENV["AWS_REGION"]
    bucket_name = event['ResourceProperties']['S3Bucket']
    prefix='/'
    execution_id = SecureRandom.uuid
    
    if bucket_name == ""
      s3_client = Aws::S3::Client.new(region: region)
      bucket_name = 'flexera-optima-' + execution_id
      
      #create the s3 bucket that will store CURs
      if bucket_created?(s3_client, bucket_name)
        puts "Bucket '#{bucket_name}' created."
      else
        raise 'Bucket creation error'
      end
      
      #Apply the bucket policy that will allow CURs to be uploaded by AWS (386209384616)
      if bucket_policy_added?(s3_client, bucket_name)
        puts "Bucket Policy Applied."
      else
        raise 'Bucket policy error'
      end
    else
      puts "Bucket '#{bucket_name}' already exist"
    end

    #Setup CUR to upload files to the s3 bucket created above.
    if report_created?(bucket_name,prefix,execution_id,region)
      puts "CUR created."
    else
      raise 'CUR creation error'
    end    
    send_response(event, context, "SUCCESS")
    
  when "Update"
    # no changes during Update to avoid re-creating bucket
    send_response(event, context, "SUCCESS")
    
  when "Delete"
    # bucket and CUR will be persisted, manual removal is required
    send_response(event, context, "SUCCESS")
    
  end

rescue Exception => e
    puts e.message
    puts e.backtrace
    send_response(event, context, "FAILED")
end

def bucket_created?(s3_client, bucket_name)
  s3_client.create_bucket(bucket: bucket_name)
  return true
rescue StandardError => e
  puts "Error creating bucket: #{e.message}"
  return false
end

def bucket_policy_added?(s3_client, bucket_name)
  bucket_policy = {
    'Version' => '2008-10-17',
    'Id' => "AWSCURPolicy",
    'Statement' => [
      {
        "Sid": "AWSBucketCURAcl",
        'Effect' => 'Allow',
        'Principal' => {  'Service' => 'billingreports.amazonaws.com' },
        'Action' => ["s3:GetBucketAcl","s3:GetBucketPolicy"],
        'Resource' => "arn:aws:s3:::#{bucket_name}"
      },
      {
        "Sid": "AWSBucketPut",
        'Effect' => 'Allow',
        'Principal' => { 'Service' => 'billingreports.amazonaws.com' },
        'Action' => "s3:PutObject",
        'Resource' => "arn:aws:s3:::#{bucket_name}/*"
      }
    ]
  }.to_json
  
  s3_client.put_bucket_policy(
    bucket: bucket_name,
    policy: bucket_policy
  )
  return true
rescue StandardError => e
  puts "Error adding bucket policy: #{e.message}"
  return false
end

def report_created?(bucket_name,prefix,execution_id,region)
  client = Aws::CostandUsageReportService::Client.new(region: region)
    resp = client.put_report_definition({
      report_definition: {
        report_name: "FlexeraOptimaCostReport" + execution_id,
        time_unit: "HOURLY",
        format: "textORcsv",
        compression: "GZIP",
        additional_schema_elements: ["RESOURCES"], # required, accepts RESOURCES
        s3_bucket: bucket_name,
        s3_prefix: prefix,
        s3_region: region, # required, accepts af-south-1, ap-east-1, ap-south-1, ap-southeast-1, ap-southeast-2, ap-northeast-1, ap-northeast-2, ap-northeast-3, ca-central-1, eu-central-1, eu-west-1, eu-west-2, eu-west-3, eu-north-1, eu-south-1, me-south-1, sa-east-1, us-east-1, us-east-2, us-west-1, us-west-2, cn-north-1, cn-northwest-1
        refresh_closed_reports: false,
        report_versioning: "CREATE_NEW_REPORT", # accepts CREATE_NEW_REPORT, OVERWRITE_REPORT
      },
    })
    return true
rescue StandardError => e
    puts "Error creating CUR: #{e.message}"
    return false
end

