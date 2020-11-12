# $LambdaInput.FlexeraRefreshToken = Flexera One API Refresh Token
# $LambdaInput.FlexeraOrgId = Flexera One Org Id
# $LambdaInput.AWSAccountId = AWS Master Payer Account Id
# $LambdaInput.AWSBucketName = AWS S3 Bucket that contains the HCUR
# $LambdaInput.AWSBucketPath = AWS S3 report prefix to the HCUR
# $LambdaInput.AWSRoleARN = AWS Role ARN created with access to bucket and Org APIs

$oauthUri = "https://login.flexera.com/oidc/token"
$oauthBody = @{
  "grant_type" = "refresh_token";
  "refresh_token"= $LambdaInput.FlexeraRefreshToken
} | ConvertTo-Json
$oauthResponse = Invoke-RestMethod -Method Post -Uri $oauthUri -Body $oauthBody -ContentType "application/json"
if (-not($null -eq $oauthResponse.access_token)) {
  Write-Output "Successfully retrieved access token"
  $accessToken = $oauthResponse.access_token
} else {
  Write-Output "Failed to retrieve access token"
}

$onboardingUri = "https://onboarding.rightscale.com/api/onboarding/orgs/$($LambdaInput.FlexeraOrgId)/bill_connects"
$onboardingHeaders = @{
  "Api-Version" = "1.0";
  "Authorization" = "Bearer $accessToken"
}
$onboardingResponse = Invoke-RestMethod -Method Get -Uri $onboardingUri -Headers $onboardingHeaders -ContentType "application/json"

if(-not($onboardingResponse.id -contains "aws-$($LambdaInput.AWSAccountId)")) {
  Write-Output "Bill connect does not exist. Creating..."
  $onboardingBody = @{
    "aws_bill_account_id"= $LambdaInput.AWSAccountId;
    "aws_bucket_name"= $LambdaInput.AWSBucketName;
    "aws_bucket_path"= $LambdaInput.AWSBucketPath;
    "aws_sts_role_arn"= $LambdaInput.AWSRoleARN;
    "aws_sts_role_session_name"= "flexera-optima"
  } | ConvertTo-Json
  $onboardingAWSResponse = Invoke-RestMethod -Method Post -Uri "$onboardingUri/aws/iam_role" -Body $onboardingBody -Headers $onboardingHeaders -ContentType "application/json"
  if (-not($null -eq $onboardingAWSResponse)) {
    Write-Output "Successfully created bill connect!"
    EXIT 0
  } else {
    Write-Output "Failed to create bill connect!"
    EXIT 1
  }
}
else {
  Write-Output "Bill connect already exists. Skipping..."
}
