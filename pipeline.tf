provider "aws" {
  region = "us-east-1"
}

variable "environment_name" {
  description = "dev or prod"
}
variable "dynamo_backup_subnet_id" {
  description = "subnet id in which pipelines will run"
}
variable "dynamo_table_to_backup" {
  description = "dynamo table you wish to back up"
}
variable "dynamo_read_throughput_ratio" {
  description = "How much of read throughput you with to dedicate for backups e.g. 0.25 means 25% of provisioned throughput"
}
variable "region" {
  description = "aws region e.g. us-east-1"
}
variable "account_id" {}
variable "key_pair" {
  description = "ec2 key-pair; use it to get access to emr cluster instances for debugging"
}

resource "aws_s3_bucket" "backup_bucket" {
  bucket = "${var.dynamo_table_to_backup}-backup-${var.environment_name}"
}

resource "aws_s3_bucket" "backup_logs_bucket" {
  bucket = "${var.dynamo_table_to_backup}-logs-${var.environment_name}"
}

resource "aws_sns_topic" "sns_backup_successful" {
  name = "${var.dynamo_table_to_backup}-dynamo-backup-successful"
}

resource "aws_sns_topic" "sns_restore_successful" {
  name = "${var.dynamo_table_to_backup}-dynamo-restore-successful"
}

resource "aws_sns_topic" "sns_backup_failed" {
  name = "${var.dynamo_table_to_backup}-dynamo-backup-failed"
}

resource "aws_cloudformation_stack" "cf_dynamo_backup_pipeline" {
  name = "${var.dynamo_table_to_backup}-dynamo-backup-cf-stack-${var.environment_name}"
  template_body = "${template_file.cf_template_dynamo_backup.rendered}"
}

resource "aws_cloudformation_stack" "cf_dynamo_restore_pipeline" {
  name = "${var.dynamo_table_to_backup}-dynamo-restore-cf-stack-${var.environment_name}"
  template_body = "${template_file.cf_template_dynamo_restore.rendered}"
}

resource "template_file" "cf_template_dynamo_backup" {
  template = "${file("${path.module}/backup-pipeline.cloudformation.json")}"
  vars {
    resource_prefix = "${var.dynamo_table_to_backup}"
    data_pipeline_resource_role = "${aws_iam_instance_profile.dynamo_backup_pipeline_iam_profile.name}"
    data_pipeline_role = "${aws_iam_role.dynamo_backup_pipeline_role.name}"
    s3_location_for_logs = "s3://${aws_s3_bucket.backup_logs_bucket.bucket}"
    s3_location_for_backup = "s3://${aws_s3_bucket.backup_bucket.bucket}"
    period = "1 Day"
    start_date_time = "2016-08-24T06:00:00"
    subnet_id = "${var.dynamo_backup_subnet_id}"
    DDBRegion = "${var.region}"
    key_pair = "${var.key_pair}"
    table_to_backup = "${var.dynamo_table_to_backup}"
    ddb_read_throughput_ratio = "${var.dynamo_read_throughput_ratio}"
    sns_arn_backup_successful = "${aws_sns_topic.sns_backup_successful.arn}"
    sns_arn_backup_failed = "${aws_sns_topic.sns_backup_failed.arn}"
  }
}

resource "template_file" "cf_template_dynamo_restore" {
  template = "${file("${path.module}/restore-pipeline.cloudformation.json")}"
  vars {
    resource_prefix = "${var.dynamo_table_to_backup}"
    data_pipeline_resource_role = "${aws_iam_instance_profile.dynamo_backup_pipeline_iam_profile.name}"
    data_pipeline_role = "${aws_iam_role.dynamo_backup_pipeline_role.name}"
    s3_location_for_logs = "s3://${aws_s3_bucket.backup_logs_bucket.bucket}"
    subnet_id = "${var.dynamo_backup_subnet_id}"
    DDBRegion = "${var.region}"
    key_pair = "${var.key_pair}"
    ddb_write_throughput_ratio = "1"
    sns_arn_backup_failed = "${aws_sns_topic.sns_backup_failed.arn}"
    sns_arn_restore_successful = "${aws_sns_topic.sns_restore_successful.arn}"
    table_to_backup = "${var.dynamo_table_to_backup}"
  }
}

resource "aws_iam_instance_profile" "dynamo_backup_pipeline_iam_profile" {
  name = "${var.dynamo_table_to_backup}-dynamo-backup-pipeline-iam-profile"
  roles = ["${aws_iam_role.dynamo_backup_pipeline_resource_role.name}"]
}

resource "aws_iam_role_policy" "dynamo_backup_pipeline_resource_role_policy" {
  name = "${var.dynamo_table_to_backup}-dynamo-backup-pipeline-role-policy"
  role = "${aws_iam_role.dynamo_backup_pipeline_resource_role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
      "Effect": "Allow",
      "Action": [
        "cloudwatch:*",
        "datapipeline:*",
        "dynamodb:*",
        "ec2:Describe*",
        "elasticmapreduce:AddJobFlowSteps",
        "elasticmapreduce:Describe*",
        "elasticmapreduce:ListInstance*",
        "elasticmapreduce:ModifyInstanceGroups",
        "rds:Describe*",
        "redshift:DescribeClusters",
        "redshift:DescribeClusterSecurityGroups",
        "s3:*",
        "sdb:*",
        "sns:*",
        "sqs:*"
      ],
      "Resource": ["*"]
    }]
}
EOF
}

resource "aws_iam_role" "dynamo_backup_pipeline_resource_role" {
  name = "${var.dynamo_table_to_backup}-dynamo-backup-pipeline-resource-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}


resource "aws_iam_role_policy" "dynamo_backup_pipeline_role_policy" {
  name = "${var.dynamo_table_to_backup}-dynamo-backup-pipeline-policy"
  role = "${aws_iam_role.dynamo_backup_pipeline_role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
      "Effect": "Allow",
      "Action": [
        "cloudwatch:*",
        "datapipeline:DescribeObjects",
        "datapipeline:EvaluateExpression",
        "dynamodb:BatchGetItem",
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:UpdateTable",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CancelSpotInstanceRequests",
        "ec2:CreateSecurityGroup",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:Describe*",
        "ec2:ModifyImageAttribute",
        "ec2:ModifyInstanceAttribute",
        "ec2:RequestSpotInstances",
        "ec2:RunInstances",
        "ec2:StartInstances",
        "ec2:StopInstances",
        "ec2:TerminateInstances",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:DeleteSecurityGroup",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:DescribeNetworkInterfaces",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DetachNetworkInterface",
        "elasticmapreduce:*",
        "iam:GetInstanceProfile",
        "iam:GetRole",
        "iam:GetRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "iam:ListInstanceProfiles",
        "iam:PassRole",
        "rds:DescribeDBInstances",
        "rds:DescribeDBSecurityGroups",
        "redshift:DescribeClusters",
        "redshift:DescribeClusterSecurityGroups",
        "s3:CreateBucket",
        "s3:DeleteObject",
        "s3:Get*",
        "s3:List*",
        "s3:Put*",
        "sdb:BatchPutAttributes",
        "sdb:Select*",
        "sns:GetTopicAttributes",
        "sns:ListTopics",
        "sns:Publish",
        "sns:Subscribe",
        "sns:Unsubscribe",
        "sqs:CreateQueue",
        "sqs:Delete*",
        "sqs:GetQueue*",
        "sqs:PurgeQueue",
        "sqs:ReceiveMessage"
      ],
      "Resource": ["*"]
    }]
}
EOF
}

resource "aws_iam_role" "dynamo_backup_pipeline_role" {
  name = "${var.dynamo_table_to_backup}-dynamo-backup-pipeline-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "datapipeline.amazonaws.com",
          "elasticmapreduce.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}