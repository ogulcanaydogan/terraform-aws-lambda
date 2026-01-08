locals {
  common_tags = merge(var.tags, { Name = var.function_name })

  # Determine if VPC access policy is needed
  attach_network_policy = var.attach_network_policy != null ? var.attach_network_policy : (var.vpc_config != null)

  # Determine if tracing policy is needed
  attach_tracing_policy = var.tracing_mode != null

  # Determine if dead letter policy is needed
  attach_dead_letter_policy = var.dead_letter_target_arn != null

  # Create zip from source path if provided
  create_package = var.source_path != null
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

################################################################################
# Zip Package from Source
################################################################################

data "archive_file" "lambda" {
  count = local.create_package ? 1 : 0

  type        = "zip"
  source_dir  = var.source_path
  output_path = "${path.module}/.terraform/lambda-${var.function_name}.zip"
}

################################################################################
# IAM Role
################################################################################

data "aws_iam_policy_document" "assume_role" {
  count = var.create_role ? 1 : 0

  statement {
    sid     = "LambdaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  count = var.create_role ? 1 : 0

  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role[0].json

  tags = local.common_tags
}

# Basic execution role (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "basic_execution" {
  count = var.create_role ? 1 : 0

  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC access role
resource "aws_iam_role_policy_attachment" "vpc_access" {
  count = var.create_role && local.attach_network_policy ? 1 : 0

  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# X-Ray tracing role
resource "aws_iam_role_policy_attachment" "xray" {
  count = var.create_role && local.attach_tracing_policy ? 1 : 0

  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Dead letter queue policy
data "aws_iam_policy_document" "dead_letter" {
  count = var.create_role && local.attach_dead_letter_policy ? 1 : 0

  statement {
    sid    = "DeadLetterAccess"
    effect = "Allow"
    actions = [
      "sns:Publish",
      "sqs:SendMessage",
    ]
    resources = [var.dead_letter_target_arn]
  }
}

resource "aws_iam_role_policy" "dead_letter" {
  count = var.create_role && local.attach_dead_letter_policy ? 1 : 0

  name   = "${var.function_name}-dead-letter"
  role   = aws_iam_role.lambda[0].id
  policy = data.aws_iam_policy_document.dead_letter[0].json
}

# Custom policy statements
data "aws_iam_policy_document" "custom" {
  count = var.create_role && length(var.policy_statements) > 0 ? 1 : 0

  dynamic "statement" {
    for_each = var.policy_statements

    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources

      dynamic "condition" {
        for_each = statement.value.conditions

        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

resource "aws_iam_role_policy" "custom" {
  count = var.create_role && length(var.policy_statements) > 0 ? 1 : 0

  name   = "${var.function_name}-custom"
  role   = aws_iam_role.lambda[0].id
  policy = data.aws_iam_policy_document.custom[0].json
}

# Additional policy attachments
resource "aws_iam_role_policy_attachment" "additional" {
  for_each = var.create_role ? toset(var.attach_policy_arns) : []

  role       = aws_iam_role.lambda[0].name
  policy_arn = each.value
}

# Event source mapping policies (SQS, DynamoDB, Kinesis, etc.)
data "aws_iam_policy_document" "event_source" {
  count = var.create_role && length(var.event_source_mappings) > 0 ? 1 : 0

  statement {
    sid    = "EventSourceAccess"
    effect = "Allow"
    actions = [
      # SQS
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      # DynamoDB Streams
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "dynamodb:DescribeStream",
      "dynamodb:ListStreams",
      # Kinesis
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:ListStreams",
      "kinesis:ListShards",
    ]
    resources = [for mapping in var.event_source_mappings : mapping.event_source_arn]
  }
}

resource "aws_iam_role_policy" "event_source" {
  count = var.create_role && length(var.event_source_mappings) > 0 ? 1 : 0

  name   = "${var.function_name}-event-source"
  role   = aws_iam_role.lambda[0].id
  policy = data.aws_iam_policy_document.event_source[0].json
}

################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.cloudwatch_logs_retention_days
  kms_key_id        = var.cloudwatch_logs_kms_key_id

  tags = local.common_tags
}

################################################################################
# Lambda Function
################################################################################

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  description   = var.description
  role          = var.create_role ? aws_iam_role.lambda[0].arn : var.role_arn

  package_type  = var.package_type
  runtime       = var.package_type == "Zip" ? var.runtime : null
  handler       = var.package_type == "Zip" ? var.handler : null
  architectures = var.architectures

  # Code source
  filename          = local.create_package ? data.archive_file.lambda[0].output_path : var.filename
  source_code_hash  = local.create_package ? data.archive_file.lambda[0].output_base64sha256 : null
  s3_bucket         = var.s3_bucket
  s3_key            = var.s3_key
  s3_object_version = var.s3_object_version
  image_uri         = var.image_uri

  memory_size = var.memory_size
  timeout     = var.timeout

  ephemeral_storage {
    size = var.ephemeral_storage_size
  }

  layers = var.layers

  reserved_concurrent_executions = var.reserved_concurrent_executions

  publish = var.publish || var.provisioned_concurrent_executions != null || length(var.aliases) > 0

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []

    content {
      variables = var.environment_variables
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []

    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  dynamic "tracing_config" {
    for_each = var.tracing_mode != null ? [var.tracing_mode] : []

    content {
      mode = tracing_config.value
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_target_arn != null ? [var.dead_letter_target_arn] : []

    content {
      target_arn = dead_letter_config.value
    }
  }

  dynamic "snap_start" {
    for_each = var.snap_start && startswith(var.runtime, "java") ? [1] : []

    content {
      apply_on = "PublishedVersions"
    }
  }

  tags = local.common_tags

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.basic_execution,
    aws_iam_role_policy_attachment.vpc_access,
    aws_iam_role_policy_attachment.xray,
  ]
}

################################################################################
# Provisioned Concurrency
################################################################################

resource "aws_lambda_provisioned_concurrency_config" "this" {
  count = var.provisioned_concurrent_executions != null ? 1 : 0

  function_name                     = aws_lambda_function.this.function_name
  provisioned_concurrent_executions = var.provisioned_concurrent_executions
  qualifier                         = aws_lambda_function.this.version
}

################################################################################
# Function URL
################################################################################

resource "aws_lambda_function_url" "this" {
  count = var.create_function_url ? 1 : 0

  function_name      = aws_lambda_function.this.function_name
  authorization_type = var.function_url_authorization_type

  dynamic "cors" {
    for_each = var.function_url_cors != null ? [var.function_url_cors] : []

    content {
      allow_credentials = cors.value.allow_credentials
      allow_headers     = cors.value.allow_headers
      allow_methods     = cors.value.allow_methods
      allow_origins     = cors.value.allow_origins
      expose_headers    = cors.value.expose_headers
      max_age           = cors.value.max_age
    }
  }
}

################################################################################
# Aliases
################################################################################

resource "aws_lambda_alias" "this" {
  for_each = var.aliases

  name             = each.key
  description      = each.value.description
  function_name    = aws_lambda_function.this.function_name
  function_version = coalesce(each.value.function_version, aws_lambda_function.this.version)

  dynamic "routing_config" {
    for_each = each.value.routing_config != null ? [each.value.routing_config] : []

    content {
      additional_version_weights = routing_config.value.additional_version_weights
    }
  }
}

################################################################################
# Event Source Mappings
################################################################################

resource "aws_lambda_event_source_mapping" "this" {
  for_each = var.event_source_mappings

  function_name                      = aws_lambda_function.this.function_name
  event_source_arn                   = each.value.event_source_arn
  batch_size                         = each.value.batch_size
  enabled                            = each.value.enabled
  starting_position                  = each.value.starting_position
  starting_position_timestamp        = each.value.starting_position_timestamp
  maximum_batching_window_in_seconds = each.value.maximum_batching_window_in_seconds
  parallelization_factor             = each.value.parallelization_factor
  maximum_record_age_in_seconds      = each.value.maximum_record_age_in_seconds
  bisect_batch_on_function_error     = each.value.bisect_batch_on_function_error
  maximum_retry_attempts             = each.value.maximum_retry_attempts
  tumbling_window_in_seconds         = each.value.tumbling_window_in_seconds

  dynamic "filter_criteria" {
    for_each = each.value.filter_criteria != null ? [each.value.filter_criteria] : []

    content {
      dynamic "filter" {
        for_each = filter_criteria.value.filters

        content {
          pattern = filter.value.pattern
        }
      }
    }
  }

  dynamic "destination_config" {
    for_each = each.value.destination_config != null ? [each.value.destination_config] : []

    content {
      on_failure {
        destination_arn = destination_config.value.on_failure.destination_arn
      }
    }
  }

  dynamic "scaling_config" {
    for_each = each.value.scaling_config != null ? [each.value.scaling_config] : []

    content {
      maximum_concurrency = scaling_config.value.maximum_concurrency
    }
  }
}

################################################################################
# Permissions (Triggers)
################################################################################

resource "aws_lambda_permission" "this" {
  for_each = var.allowed_triggers

  function_name      = aws_lambda_function.this.function_name
  statement_id       = each.key
  action             = "lambda:InvokeFunction"
  principal          = each.value.principal
  source_arn         = each.value.source_arn
  source_account     = each.value.source_account
  event_source_token = each.value.event_source_token
}

# Function URL public access permission
resource "aws_lambda_permission" "function_url" {
  count = var.create_function_url && var.function_url_authorization_type == "NONE" ? 1 : 0

  function_name          = aws_lambda_function.this.function_name
  statement_id           = "FunctionURLAllowPublicAccess"
  action                 = "lambda:InvokeFunctionUrl"
  principal              = "*"
  function_url_auth_type = "NONE"
}
