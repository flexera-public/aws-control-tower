require 'aws-sdk'
require 'securerandom'
require 'json'

def lambda_handler(event:, context:)
    { event: JSON.generate(event), context: JSON.generate(context.inspect) }
    
  region = ENV["AWS_REGION"]
  s3_client = Aws::S3::Client.new(region: region)
  execution_id = SecureRandom.uuid
  bucket_name = 'flexera-optima-' + execution_id
  prefix='/'

  #create the s3 bucket that will store CURs
  if bucket_created?(s3_client, bucket_name)
    puts "Bucket '#{bucket_name}' created."
  else
    puts "Bucket '#{bucket_name}' not created."
    exit 1
  end
  
  #Apply the bucket policy that will allow CURs to be uploaded by AWS (386209384616)
  if bucket_policy_added?(s3_client, bucket_name)
    puts "Bucket Policy Applied."
  else
    puts "Bucket Policy Not Applied (ERROR)."
    exit 1
  end
  
  #Setup CUR to upload files to the s3 bucket created above.
  if createReport?(bucket_name,prefix,execution_id)
    puts "CUR created."
  else
    puts "CUR not created."
    exit 1
  end
  
    
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
    'Id' => "Policy1335892530063",
    'Statement' => [
      {
        "Sid": "Stmt1335892150622",
        'Effect' => 'Allow',
        'Principal' => { 'AWS' => 'arn:aws:iam::386209384616:root' },
        'Action' => ["s3:GetBucketAcl","s3:GetBucketPolicy"],
        'Resource' => "arn:aws:s3:::#{bucket_name}"
      },
      {
        "Sid": "Stmt1335892526596",
        'Effect' => 'Allow',
        'Principal' => { 'AWS' => 'arn:aws:iam::386209384616:root' },
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


def createReport?(bucket_name,prefix,execution_id)
  region = ENV["AWS_REGION"]
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

