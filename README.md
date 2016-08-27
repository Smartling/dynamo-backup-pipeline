# dynamo-backup-pipeline
Terraform module to backup dynamo table. It will scan and copy all items from target table into s3 bucket daily and run a verification. In case of ony failures it will send a notification to  **TableName-dynamo-backup-failed** sns topic.

#How to use it

Put this in your terraform file and run terraform apply:
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
Note that you can specify git branch,commit or tag. It is strongly advised to use git tags so that the code of a module won't change for you with someone committing into a repository.

- **environment_name** - It's just a suffix for s3 buckets in case you want to have setup for -your dev and prod environments together. Could be any string.
- **dynamo_backup_subnet_id** - Subnet Id in which datapipeline will run. It must be a public subnet.
- **dynamo_table_to_backup** - Name of a table you wish to back up.
- **dynamo_read_throughput_ratio** - How much of read throughput you with to dedicate for backups e.g. 0.25 means 25% of provisioned throughput
-  **region** - AWS region
-  **account_id** - AWS account id
-  **key_pair** - ec2 key-pair, use it to get access to emr cluster instances for debugging
-  **dynamo_backup_period** - How often should pipeline run
-  **dynamo_backup_start_date_time** - When should backup start

Don't forget to subscribe to a sns topic TableName-dynamo-backup-failed to get notified of any failures.

To restore a backup:
```start-table-restore-pipeline.sh s3://SourceTableName-backup-prod/2016-08-25-06-00-00 SourceTableName DestinationTableName```

#How it works
Module consists of 2 pipelines (TableName-dynamo-backup-pipeline & TableName-dynamo-restore-pipeline). Datapipeline runs backup pipeline on a schedule. This pipeline backs up all the records into S3 bucket s3://TableName-backup-prod/CurrentDate once it's finished it triggers a lambda function that: Creates a dynamo table with the same schema as the original table and starts a restore pipeline. Once the restore pipeline finishes it triggers another lambda that verifies that the restored data is the same as in the original table. If anything fails along the way (any of the pipelines fail or lambdas) you'll get notified via sns.

#Limitations
1. It's not a point in time snapshot! Backup pipeline simply scans the whole table and saves all the records it finds into s3 bucket. No magic here.
2. Pipeline runs on a schedule which means that you won't be able to restore to an arbitrary point in time. You can loose all the data that is generated after the last backup.
