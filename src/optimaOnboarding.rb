require 'aws-sdk'
require 'securerandom'
require 'json'
require "cfn_response"
require 'faraday'

def lambda_handler(event:, context:)
  cfn = CfnResponse.new(event, context)
  cfn.response do
    case event['RequestType']
    when "Create"
      region = ENV["AWS_REGION"]
      bucket_name = event['ResourceProperties']['S3Bucket']
      prefix = event['ResourceProperties']['S3Prefix']
      execution_id = SecureRandom.uuid
      s3_client = Aws::S3::Client.new(region: region)
      
      if bucket_name == ""
        bucket_name = 'flexera-optima-' + execution_id
        report_name = 'FlexeraOptimaCostReport-' + execution_id
        prefix = 'cloudcost/'
        
        #create the s3 bucket that will store CURs
        if bucket_created?(s3_client, bucket_name)
          puts "Bucket '#{bucket_name}' created."
          #Apply the bucket policy that will allow CURs to be uploaded by AWS (386209384616)
          if bucket_policy_added?(s3_client, bucket_name)
            puts "Bucket Policy Applied."
          else
            raise 'Bucket policy error'
          end
        else
          raise 'Bucket creation error'
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
      
      data = {
        'bucket_name' => "#{bucket_name}",
        'report_name' => "#{report_name}",
        'prefix' => "#{prefix}"
        }
      cfn.success(Data: data)
      
    when "Update"
      # no changes during Update to avoid re-creating bucket
      cfn.success
      
    when "Delete"
      # bucket and CUR will be persisted, manual removal is required
      cfn.success
    end
    
  end

rescue Exception => e
    puts e.message
    puts e.backtrace
    sleep 10 # a little time for logs to be sent to CloudWatch
    cfn.failed
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
  client = Aws::CostandUsageReportService::Client.new(region: 'us-east-1')
    resp = client.put_report_definition({
      report_definition: {
        report_name: "FlexeraOptimaCostReport-" + execution_id,
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


def billconnect_handler(event:, context:)
  cfn = CfnResponse.new(event, context)
  cfn.response do
    case event['RequestType']
    when "Create"
      refresh_token = event['ResourceProperties']['RefreshToken']
      account_id = event['ResourceProperties']['AccountId']
      bucket_name = event['ResourceProperties']['S3Bucket']
      prefix = event['ResourceProperties']['S3Prefix']
      role_arn = event['ResourceProperties']['RoleARN']
      flexera_org_id = event['ResourceProperties']['FlexeraOrgId']
      
      #Flexera Authentication
      access_token = get_access_token(refresh_token)
      
      #account_id = AWS Payer Account
      #bucket_name = bucket where CUR has been configured
      #prefix = prefix used for CUR configuration
      #role_arn = arn of role created via CFT
      #flexera_org_id = the flexera organization id 
      
      #connect the aws billing data with Flexera
      bill_connect(account_id,bucket_name,prefix,role_arn,flexera_org_id,access_token)
      cfn.success
    
    when "Update"
      # no changes during Update to avoid re-creating bucket
      cfn.success
      
    when "Delete"
      # bucket and CUR will be persisted, manual removal is required
      cfn.success
    
    end
  end
  
rescue Exception => e
    puts e.message
    puts e.backtrace
    sleep 10 # a little time for logs to be sent to CloudWatch
    cfn.failed
end

def get_access_token(refresh_token)
  oauth_uri = "https://login.flexera.com/oidc/token"
  oauth_body = {
      "grant_type" => "refresh_token",
      "refresh_token" => refresh_token,
  }.to_json

  resp = Faraday.post(oauth_uri, oauth_body,"Content-Type" => "application/json")

  if resp.status == 200
      puts "Successfully retrieved access token" 
      access_token = JSON.parse(resp.body)["access_token"]
      return access_token
  else
      puts "Failed to retrieve access token"
      puts resp.status
      puts resp.body
  end
end

def bill_connect(account_id,s3_bucket,s3_prefix,role_arn,flexera_org_id,access_token)
  onboarding_uri = "https://onboarding.rightscale.com/api/onboarding/orgs/#{flexera_org_id}/bill_connects/aws/iam_role"
  onboarding_headers = {
      "Api-Version" => "1.0",
      "Authorization" => "Bearer #{access_token}",
      "Content-Type" => "application/json"
  }
  onboarding_body = {
      "aws_bill_account_id" => account_id,
      "aws_bucket_name" => s3_bucket,
      "aws_bucket_path"=> s3_prefix,
      "aws_sts_role_arn" => role_arn,
      "aws_sts_role_session_name" => "flexera_optima"
  }.to_json

  resp = Faraday.post(onboarding_uri,onboarding_body,onboarding_headers)

  if resp.status == 201
      puts "Successfully created the bill connect" 
  else
      puts "Failed to create the bill connect"
      puts resp.status
      puts resp.body
  end
end