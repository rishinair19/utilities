#!/bin/bash

function_name=""
layers=("")
memory_size=128
runtime="python3.9"
timeout=120
security_group=""
branch=dev                              # Values can be dev or master
s3_trigger="yes"                        # Set to yes if S3 trigger is required
bucket_name=""           # Applicable only if s3_trigger is set to yes. Set name of bucket which should trigger this lambda function
iam_required="yes"                      # Set yes if you need script to create Cloudwatch and VPC Role
subnet_ids=()   # Specify subnet IDs here, you can get them for AWS Console

#################################################################################################################################################################################


resource_name=$(echo "$function_name" | tr '[:upper:]' '[:lower:]' | tr '-' '_')

if [ "$branch" == "dev" ]; then
    s3_bucket=""
    account_id=""
elif [ "$branch" == "prod" ]; then
    s3_bucket=""
    account_id=""
else
    echo "Unknown branch: $branch"
    exit 1
fi

echo "Provide keys which have S3 access for $branch profile"

aws configure
s3_path=$function_name/$function_name.zip
aws s3 cp sample-code.zip s3://$s3_bucket/$s3_path


# Generate Terraform resource
cat <<EOL > lambda_function.tf
# aws_lambda_function.$resource_name:
resource "aws_lambda_function" "$resource_name" {
    architectures                  = [
        "x86_64",
    ]
    function_name                  = "$function_name"
    s3_bucket                      = "$s3_bucket"
    s3_key                         = "$s3_path"
    handler                        = "lambda_function.lambda_handler"
    layers                         = [
        "${layers[0]}",
    ]
    memory_size                    = $memory_size
    package_type                   = "Zip"
    reserved_concurrent_executions = -1
    role                           = aws_iam_role.$resource_name.arn
    runtime                        = "$runtime"
    skip_destroy                   = false
    tags                           = {}
    tags_all                       = {}
    timeout                        = $timeout

    ephemeral_storage {
        size = 512
    }

    logging_config {
        log_format = "Text"
        log_group  = "/aws/lambda/$function_name"
    }

    tracing_config {
        mode = "PassThrough"
    }

    vpc_config {
        ipv6_allowed_for_dual_stack = false
        security_group_ids          = [
            "$security_group",
        ]
        subnet_ids                  = [
EOL

# Dynamically append subnet IDs to the lambda_function.tf file
for subnet in "${subnet_ids[@]}"; do
    echo "            \"$subnet\"," >> lambda_function.tf
done

# Close the VPC config block
cat <<EOL >> lambda_function.tf
        ]
    }
}
EOL

if [ "$iam_required" == "yes" ]; then
    cat <<EOL >> lambda_function.tf

resource "aws_iam_role" "$resource_name" {
  assume_role_policy = data.aws_iam_policy_document.$resource_name.json

  managed_policy_arns  = ["arn:aws:iam::$account_id:policy/LambdaVPCPermission"]
  max_session_duration = "3600"
  name                 = "$resource_name"
  path                 = "/service-role/"
}

data "aws_iam_policy_document" "$resource_name" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "${resource_name}_vpc" {
  policy_arn = "arn:aws:iam::$account_id:policy/LambdaVPCPermission"
  role       = aws_iam_role.$resource_name.name
}

resource "aws_iam_role_policy_attachment" "${resource_name}_cloudwatch" {
  policy_arn = aws_iam_policy.$resource_name.arn
  role       = aws_iam_role.$resource_name.name
}


resource "aws_iam_policy" "$resource_name" {
  name   = "AWSLambdaBasicExecutionRole-$resource_name"
  path   = "/service-role/"
  policy = data.aws_iam_policy_document.${resource_name}_cloudwatch.json
}

data "aws_iam_policy_document" "${resource_name}_cloudwatch" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:logs:us-east-1:$account_id:*"]
    actions   = ["logs:CreateLogGroup"]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:logs:us-east-1:$account_id:log-group:/aws/lambda/$function_name:*"]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}

EOL
fi

# If S3 trigger is enabled, generate additional Terraform blocks for S3 trigger
if [ "$s3_trigger" == "yes" ]; then
    cat <<EOL >> lambda_function.tf


# aws_lambda_permission.$resource_name:
resource "aws_lambda_permission" "$resource_name" {
    action         = "lambda:InvokeFunction"
    function_name  = aws_lambda_function.$resource_name.arn
    principal      = "s3.amazonaws.com"
    source_arn     = "arn:aws:s3:::$bucket_name"
}

# aws_s3_bucket_notification.$resource_name:
resource "aws_s3_bucket_notification" "$resource_name" {
    bucket      = "$bucket_name"
    eventbridge = false
    lambda_function {
        events              = [
            "s3:ObjectCreated:*",
        ]
        lambda_function_arn = aws_lambda_function.$resource_name.arn
    }
}
EOL
fi

echo "Terraform configuration generated in lambda_function.tf"

cat lambda_function.tf