require 'json'
require 'faraday'
require "cfnresponse"
include Cfnresponse

def lambda_handler(event:, context:)
    refresh_token = event['ResourceProperties']['S3Bucket']

    get_access_token(refresh_token)

end

def get_access_token(refresh_token)
    oauth_uri = "https://login.flexera.com/oidc/token"
    oauth_body = {
        "grant_type" => "refresh_token",
        "refresh_token" => refresh_token,
    }.to_json

    resp = Faraday.post(oauth_uri, oauth_body,
        "Content-Type" => "application/json")

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
    onboarding_uri = "https://onboarding.rightscale.com/api/onboarding/orgs/#{flexera_org_id}/bill_connects"
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

    puts onboarding_uri
    puts onboarding_body
    puts onboarding_headers
    #resp = Faraday.post(onboarding_uri,onboarding_body,onboarding_headers)

end

bill_connect(123,'flxoptima','assets/','arn:adfasdfasdf:role',7954,'ajsdlfajlsdfjlasdjfjaslkdjasjd')







 
