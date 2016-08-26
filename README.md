# dynamo-backup-pipeline
Terraform module to backup dynamo table. It will scan and copy all items from target table into s3 bucket daily and run a verification. In case of ony failures it will send a notification to  **TableName-dynamo-backup-failed sns topic.** Unfortunately it's impossible to subscribe via terraform, so you'll need to subscribe your team  to this topic yourself to get notified.

To use it put this in your terraform file. Note that you can specify git branch,commit or tag:
```
module "dynamo_backup" {
  source = "git@github.com:Smartling/dynamo-backup-pipeline.git?ref=<branch|commit|tag>"
  environment_name = "dev"
  dynamo_backup_subnet_id = "subnet-123456789"
  dynamo_table_to_backup = "TableName"
  dynamo_read_throughput_ratio = "0.25"
  region = "us-east-1"
  account_id = "12356789012"
  key_pair = "ec2-key-pair"
  dynamo_backup_period = "1 Day"
  dynamo_backup_start_date_time = "2016-08-24T06:00:00"
}
```
To restore a backup:
`start-table-restore-pipeline.sh s3://SourceTableName-backup-prod/2016-08-25-06-00-00 SourceTableName DestinationTableName"`
