resource "aws_iam_role_policy" "start_verify_restore_lambda_role_policy" {
  name = "${var.dynamo_table_to_backup}-start_verify_restore_lambda_role_policy"
  role = "${aws_iam_role.start_verify_restore_lambda_role.id}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:${var.region}:${var.account_id}:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/${aws_lambda_function.start_verify_restore_lambda.function_name}:*"
            ]
        },
        {
          "Effect": "Allow",
          "Action": [
                "datapipeline:ListPipelines",
                "datapipeline:DescribePipelines",
                "datapipeline:ActivatePipeline"
                ],
          "Resource": "*"
        },
        {
          "Effect":"Allow",
          "Action":"iam:PassRole",
          "Resource":"${aws_iam_role.dynamo_backup_pipeline_role.arn}"
        },
        {
          "Effect": "Allow",
          "Action": [
                "dynamodb:DescribeTable",
                "dynamodb:CreateTable"
                ],
          "Resource": "*"
        },
        {
          "Effect": "Allow",
          "Action": "dynamodb:DeleteTable",
          "Resource": "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${var.dynamo_table_to_backup}-backup_verification_temp_table*"
        }
    ]
}
EOF
}

resource "aws_iam_role" "start_verify_restore_lambda_role" {
  name = "${var.dynamo_table_to_backup}-start_verify_restore_lambda_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "start_verify_restore_lambda" {
  lifecycle {
    ignore_changes = [
      "filename",
      "source_code_hash"]
  }
  depends_on = ["null_resource.start_restore_verification_lambda_zip_file"]
  filename = "${path.module}/${var.start_restore_verification_lambda_name}.zip"
  function_name = "${var.dynamo_table_to_backup}-${var.start_restore_verification_lambda_name}"
  role = "${aws_iam_role.start_verify_restore_lambda_role.arn}"
  handler = "${var.start_restore_verification_lambda_name}.lambda_handler"
  source_code_hash = "${base64sha256(file("${path.module}/${var.start_restore_verification_lambda_name}.zip"))}"
  runtime = "python2.7"
  timeout = "10"
  memory_size = "128"
}

variable "start_restore_verification_lambda_name" {
  default = "start_restore_verification_lambda"
}

resource "null_resource" "start_restore_verification_lambda_zip_file" {
  provisioner "local-exec" {
    command = "rm ${path.module}/${var.start_restore_verification_lambda_name}.zip; zip ${path.module}/${var.start_restore_verification_lambda_name}.zip ${path.module}/${var.start_restore_verification_lambda_name}.py -j"
  }
}

resource "aws_lambda_permission" "start_restore_verification_lambda_sns_permissions" {
  statement_id = "AllowExecutionFromSNS"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.start_verify_restore_lambda.arn}"
  principal = "sns.amazonaws.com"
  source_arn = "${aws_sns_topic.sns_backup_successful.arn}"
}

resource "aws_sns_topic_subscription" "start_restore_verification_lambda_subscription" {
  topic_arn = "${aws_sns_topic.sns_backup_successful.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.start_verify_restore_lambda.arn}"
}

resource "aws_cloudwatch_metric_alarm" "start_verify_restore_ambda_fails_alarm" {
  alarm_name = "${var.dynamo_table_to_backup}-DynamoStartRestoreVerificationFailedAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "1"
  metric_name = "Errors"
  namespace = "AWS/Lambda"
  period = "60"
  statistic = "Average"
  threshold = "1"
  dimensions {
    FunctionName = "${aws_lambda_function.start_verify_restore_lambda.function_name}"
  }
  alarm_description = "Restore fails"
  alarm_actions = ["${aws_sns_topic.sns_backup_failed.arn}"]
}