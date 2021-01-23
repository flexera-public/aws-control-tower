#!/bin/bash
QSS3BucketName=$1
QSS3KeyPrefix=$2
SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
pushd $SCRIPT_DIRECTORY > /dev/null
cd src
bundle install --path vendor/bundle
zip -r optimaOnboarding.zip optimaOnboarding.rb vendor
popd > /dev/null
aws s3 cp ./src/optimaOnboarding.zip  s3://$QSS3BucketName/$QSS3KeyPrefix/optimaOnboarding.zip --acl public-read
aws s3 cp ./template/flexeraOptimaAWSControlTower.yaml s3://$QSS3BucketName/$QSS3KeyPrefix/flexeraOptimaAWSControlTower.yaml --acl public-read