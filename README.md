# dynamo-backup-pipeline
Terraform module to backup dynamo table
It will back up a target table into s3 bucket daily and run a verification.
In case of ony failures it will send a notification to  TableName-dynamo-backup-failed sns topic.
You'll need to subscribe your team email to it to get notified.

put this in your tf file to use it:
module "dynamo_backup" {
  source = "git@github.com:Smartling/dynamo-backup-pipeline.git?ref=v1.0"
  environment_name = "dev"
  dynamo_backup_subnet_id = "subnet-123456789"
  dynamo_table_to_backup = "TableName"
  dynamo_read_throughput_ratio = "0.25"
  region = "us-east-1"
  account_id = "12356789012"
  key_pair = "ec2-key-pair"
}

how to restore backup manually:
start-table-restore-pipeline.sh s3://bucket/2016-08-25-06-00-00 SourceTableName DestinationTableName"
