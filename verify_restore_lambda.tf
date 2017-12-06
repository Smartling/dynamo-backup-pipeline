resource "aws_iam_role_policy" "verify_restore_lambda_role_policy" {
  name = "${var.dynamo_table_to_backup}-verify_restore_lambda_role_policy"
  role = "${aws_iam_role.verify_restore_lambda_role.id}"
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
                "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/${aws_lambda_function.verify_restore_lambda.function_name}:*"
            ]
        },
        {
          "Effect": "Allow",
          "Action": ["dynamodb:DescribeTable",
                     "dynamodb:Scan"
                    ],
          "Resource": "*"
        },
        {
          "Effect": "Allow",
          "Action": ["dynamodb:DeleteTable",
                     "dynamodb:GetItem"
                    ],
          "Resource": "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${var.dynamo_table_to_backup}-backup_verification_temp_table*"
        }
    ]
}

EOF
}

resource "aws_iam_role" "verify_restore_lambda_role" {
  name = "${var.dynamo_table_to_backup}-verify_restore_lambda_role"
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

resource "aws_lambda_function" "verify_restore_lambda" {
  filename = "${substr(data.archive_file.verify_restore_lambda_lambda_zip.output_path, length(path.cwd) + 1, -1)}"
  function_name = "${var.dynamo_table_to_backup}-verify_restore_lambda"
  role = "${aws_iam_role.verify_restore_lambda_role.arn}"
  handler = "${var.verify_restore_lambda_name}.lambda_handler"
  source_code_hash = "${data.archive_file.verify_restore_lambda_lambda_zip.output_base64sha256}"
  runtime = "python2.7"
  timeout = "3"
  memory_size = "128"
}

variable "verify_restore_lambda_name" {
  default = "verify_restore_lambda"
}

data "archive_file" "verify_restore_lambda_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/source"
  output_path = "${path.module}/${var.verify_restore_lambda_name}.zip"
}

resource "aws_lambda_permission" "verify_restore_lambda_sns_permissions" {
  statement_id = "AllowExecutionFromSNS"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.verify_restore_lambda.arn}"
  principal = "sns.amazonaws.com"
  source_arn = "${aws_sns_topic.sns_restore_successful.arn}"
}

resource "aws_sns_topic_subscription" "verify_restore_lambda_subscription" {
  topic_arn = "${aws_sns_topic.sns_restore_successful.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.verify_restore_lambda.arn}"
}

resource "aws_cloudwatch_metric_alarm" "verify_restore_lambda_fails_alarm" {
  alarm_name = "${var.dynamo_table_to_backup}-DynamoRestoreVerificationFailedAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "1"
  metric_name = "Errors"
  namespace = "AWS/Lambda"
  period = "60"
  statistic = "Average"
  threshold = "1"
  dimensions {
    FunctionName = "${aws_lambda_function.verify_restore_lambda.function_name}"
  }
  alarm_description = "Restore fails"
  alarm_actions = ["${aws_sns_topic.sns_backup_failed.arn}"]
}
