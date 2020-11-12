require 'aws-sdk'



def handler(event:, context:)
    { event: JSON.generate(event), context: JSON.generate(context.inspect) }
end

def createS3Bucket(region_name,bucket_name){
  resp = client.create_bucket({
    bucket: bucket_name,
    create_bucket_configuration: {
      location_constraint: region_name,
    },
  })

}


def createReport(region_name,credentials,bucket_name,prefix){
  client = Aws::CostandUsageReportService::Client.new(
    region: region_name,
    credentials: credentials,


    resp = client.put_report_definition({
      report_definition: {
        report_name: "FlexeraOptimaCostReport",
        time_unit: "HOURLY",
        format: "textORcsv",
        compression: "GZIP",
        additional_schema_elements: ["RESOURCES"], # required, accepts RESOURCES
        s3_bucket: "S3Bucket",
        s3_prefix: "S3Prefix",
        s3_region: "af-south-1", # required, accepts af-south-1, ap-east-1, ap-south-1, ap-southeast-1, ap-southeast-2, ap-northeast-1, ap-northeast-2, ap-northeast-3, ca-central-1, eu-central-1, eu-west-1, eu-west-2, eu-west-3, eu-north-1, eu-south-1, me-south-1, sa-east-1, us-east-1, us-east-2, us-west-1, us-west-2, cn-north-1, cn-northwest-1
        refresh_closed_reports: false,
        report_versioning: "CREATE_NEW_REPORT", # accepts CREATE_NEW_REPORT, OVERWRITE_REPORT
      },
    })
  )

}
