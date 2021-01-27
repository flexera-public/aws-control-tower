require 'json'
require 'faraday'
require "cfnresponse"
include Cfnresponse

def lambda_handler(event:, context:)
    puts("Received event: " + json_pretty(event))

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

    when "Update"
    # no update method defined.
    send_response(event, context, "SUCCESS")
    
    when "Delete"
    # no delete method defined
    send_response(event, context, "SUCCESS")
    
    rescue Exception => e
        puts e.message
        puts e.backtrace
        send_response(event, context, "FAILED")
    end

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