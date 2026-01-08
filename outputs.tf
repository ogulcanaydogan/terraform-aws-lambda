# Function
output "function_name" {
  description = "Lambda function name."
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "Lambda function ARN."
  value       = aws_lambda_function.this.arn
}

output "function_qualified_arn" {
  description = "Lambda function qualified ARN (with version)."
  value       = aws_lambda_function.this.qualified_arn
}

output "function_invoke_arn" {
  description = "Lambda function invoke ARN (for API Gateway)."
  value       = aws_lambda_function.this.invoke_arn
}

output "function_version" {
  description = "Latest published version."
  value       = aws_lambda_function.this.version
}

output "function_qualified_invoke_arn" {
  description = "Lambda function qualified invoke ARN."
  value       = aws_lambda_function.this.qualified_invoke_arn
}

output "function_source_code_hash" {
  description = "Source code hash."
  value       = aws_lambda_function.this.source_code_hash
}

output "function_source_code_size" {
  description = "Source code size in bytes."
  value       = aws_lambda_function.this.source_code_size
}

output "function_last_modified" {
  description = "Last modified timestamp."
  value       = aws_lambda_function.this.last_modified
}

output "signing_job_arn" {
  description = "Signing job ARN."
  value       = aws_lambda_function.this.signing_job_arn
}

output "signing_profile_version_arn" {
  description = "Signing profile version ARN."
  value       = aws_lambda_function.this.signing_profile_version_arn
}

# IAM
output "role_name" {
  description = "Lambda IAM role name."
  value       = try(aws_iam_role.lambda[0].name, null)
}

output "role_arn" {
  description = "Lambda IAM role ARN."
  value       = try(aws_iam_role.lambda[0].arn, var.role_arn)
}

output "role_id" {
  description = "Lambda IAM role ID."
  value       = try(aws_iam_role.lambda[0].id, null)
}

# CloudWatch Logs
output "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group name."
  value       = aws_cloudwatch_log_group.lambda.name
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch Log Group ARN."
  value       = aws_cloudwatch_log_group.lambda.arn
}

# Function URL
output "function_url" {
  description = "Lambda Function URL."
  value       = try(aws_lambda_function_url.this[0].function_url, null)
}

output "function_url_id" {
  description = "Lambda Function URL ID."
  value       = try(aws_lambda_function_url.this[0].url_id, null)
}

# Aliases
output "aliases" {
  description = "Map of Lambda aliases."
  value = {
    for key, alias in aws_lambda_alias.this : key => {
      arn              = alias.arn
      invoke_arn       = alias.invoke_arn
      function_version = alias.function_version
    }
  }
}

# Event Source Mappings
output "event_source_mapping_uuids" {
  description = "Map of event source mapping UUIDs."
  value = {
    for key, mapping in aws_lambda_event_source_mapping.this : key => mapping.uuid
  }
}

output "event_source_mapping_arns" {
  description = "Map of event source mapping ARNs."
  value = {
    for key, mapping in aws_lambda_event_source_mapping.this : key => mapping.function_arn
  }
}

# Invocation examples
output "invoke_command" {
  description = "AWS CLI command to invoke the function."
  value       = "aws lambda invoke --function-name ${aws_lambda_function.this.function_name} --payload '{}' response.json"
}

output "logs_command" {
  description = "AWS CLI command to view recent logs."
  value       = "aws logs tail /aws/lambda/${aws_lambda_function.this.function_name} --follow"
}
