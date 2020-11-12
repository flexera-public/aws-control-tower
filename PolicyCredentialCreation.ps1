# $LambdaInput.FlexeraRefreshToken = Flexera One API Refresh Token
# $LambdaInput.FlexeraOrgId = Flexera One Org Id
# $LambdaInput.AWSAccountId = AWS Master Payer Account Id
# $LambdaInput.AWSRoleARN = AWS Role ARN created with access to bucket and Org APIs

function Index-Credentials ($Shard, $AccessToken, $ProjectId) {
  try {
    Write-Output "Indexing credentials in Project ID: $ProjectId..."

    $contentType = "application/json"

    $header = @{
      "Api-Version"="1.0";
      "Authorization"="Bearer $AccessToken"}
    $uri = "https://cloud-$shard.rightscale.com/cloud/projects/$ProjectId/credentials?scheme=aws_sts"
    Write-Output "URI: $uri"

    $credsResult = Invoke-RestMethod -UseBasicParsing -Uri $uri -Method Get -Headers $header -ContentType $contentType

    return $credsResult
  }
  catch {
      Write-Output "Error retrieving credentials! $($_ | Out-String)"
  }
}

function Show-Credential ($Shard, $AccessToken, $ProjectId, $CredentialId) {
  try {
    Write-Output "Showing credential $CredentialId in Project ID: $ProjectId..."

    $contentType = "application/json"

    $header = @{
      "Api-Version"="1.0";
      "Authorization"="Bearer $AccessToken"}
    $uri = "https://cloud-$shard.rightscale.com/cloud/projects/$ProjectId/credentials/aws_sts/$CredentialId"
    Write-Output "URI: $uri"

    $credsResult = Invoke-RestMethod -UseBasicParsing -Uri $uri -Method Get -Headers $header -ContentType $contentType

    return $credsResult
  }
  catch {
      Write-Output "Error retrieving credentials! $($_ | Out-String)"
  }
}

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

# Get Master Account Id
$grsHeader = @{
  "X_API_VERSION" = "2.0";
  "Authorization" = "Bearer $accessToken"
}
$grsResponse = Invoke-RestMethod -Uri "https://governance.rightscale.com/grs/orgs/$($LambdaInput.FlexeraOrgId)" -Method Get -Headers $grsHeader -ContentType "application/json"
if($null -ne $grsResponse) {
  $shard = $grsResponse.legacy.account_url.Replace("https://","").Split(".")[0].Split("-")[1]
  $masterAccount = $grsResponse.legacy.account_url.Split("/")[-1]
  Write-Output "Shard: $shard"
  Write-Output "Master Account Id: $masterAccount"
}
else {
  Write-Output "Error retrieveing org details"
}

$existingCreds = Index-Credentials -AccessToken $accessToken -Shard $shard -ProjectId $masterAccount
if($existingCreds.count -gt 0) {
  $awsCreds = @()
  foreach ($cred in $existingCreds.items) {
    $awsCreds += Show-Credential -ProjectId $masterAccount -AccessToken $accessToken -Shard $shard -CredentialId $cred.id
  }
}

if(-not($awsCreds.role_arn -contains $LambdaInput.AWSRoleARN)) {
  Write-Output "Credential does not exist. Creating..."
  $credHeader = @{
    "Api-Version"="1.0";
    "Authorization"="Bearer $AccessToken"}
  $credId = "AWS_$($LambdaInput.AWSAccountId)"
  $credBody = @{
    "external_id"= $LambdaInput.FlexeraOrgId;
    "name"= $credId;
    "description"="Created via AWS Control Tower"
    "role_arn"= $LambdaInput.AWSRoleARN;
    "role_session_name"="flexera-policies";
    "tags"=@(
      @{
        "key"="provider";
        "value"="aws";
      };
      @{
        "key"="ui";
        "value"="aws_sts";
      }
    )
  } | ConvertTo-Json
  $credResponse = Invoke-WebRequest -Method Put -Uri "https://cloud-$shard.rightscale.com/cloud/projects/$masterAccount/credentials/aws_sts/$credId" -Body $credBody -Headers $credHeader -ContentType "application/json"
  if ($credResponse.StatusCode -eq 201) {
    Write-Output "Successfully created credential!"
    EXIT 0
  } else {
    Write-Output "Failed to create credential!"
    EXIT 1
  }
}
else {
  Write-Output "Credential already exists. Skipping..."
}
