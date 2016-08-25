#!/bin/bash
set -x
if [ -z "$3" ]
  then
    echo "Starts a pipeline to restore a dynamo table from s3
start-table-restore-pipeline.sh <backup_s3_bucket_path> <backup_table> <restore_table>
backup_s3_bucket_path - s3 path to a backup e.g.
<backup_table> - table you backed up from
<restore_table> - table you are restoring into(could be the same one)

Example:
start-table-restore-pipeline.sh s3://bucket/2016-08-25-06-00-00 SourceTableName DestinationTableName"
exit
fi
s3folder=$1
backup_table=$2
restore_table=$3
pipeline_id=$(aws datapipeline list-pipelines | grep ${backup_table}-dynamo-restore-pipeline | cut -f2)
aws datapipeline activate-pipeline --pipeline-id ${pipeline_id} --parameter-values my_source_s3_folder=${s3folder} my_destination_dynamo_table=${restore_table}
