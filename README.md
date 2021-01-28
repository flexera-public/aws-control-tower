![alt text](https://github.com/flexera/aws-control-tower/blob/main/aws-control-tower.png?raw=true)

# Flexera Optima Integration with AWS Control Tower

This repository provides all assets used to integrate Flexera Optima with AWS Control Tower.

## Integration Guide

Follow the steps in the  [Flexera Optima Integration Guide](https://linktodguide.) to complete the integration.

## Usage
- Launch the template `flexeraOptimaAWSControlTower` on your AWS Control Tower Management / Payer account
- Enter all the required parameters

    ####  FlexeraOrgId
    ##### `The Id of your Flexera Organization` [[documentation]](https://docs.flexera.com/flexera/EN/FlexeraAPI/OrgID.htm)
    ### RefreshToken 
    ##### `RefreshToken from the Flexera Platform.` [[documentation]](https://docs.flexera.com/flexera/EN/FlexeraAPI/GenerateRefreshToken.htm)
    ### S3Bucket 
    ##### `The name of the S3 bucket where your Hourly Cost and Usage Report is stored. Leave it empty to allow for auto-create.`
    ### QSS3BucketName
    ##### `Flexera S3 bucket where the Lambda function package resides, do not modify this unless you are required by Flexera team`
    ### QSS3KeyPrefix
    ##### `Flexera S3 bucket prefix where the Lambda function package resides, do not modify this unless you are required by Flexera team`


## Build
run 'build.sh' by specifying the S3 bucket and prefix where you want to store the Lambda package

example:

```
build.sh my_bucket_name my_prefix
```


## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.


## License
[APACHE2.0](https://github.com/flexera/aws-control-tower/blob/main/LICENSE)

