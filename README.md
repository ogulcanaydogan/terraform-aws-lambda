# terraform-aws-lambda

Terraform module that creates AWS Lambda functions with IAM roles, event source mappings, Function URLs, and monitoring.

## Features

- **Multiple Runtimes** - Python, Node.js, Java, Go, .NET, Ruby, and custom runtimes
- **Container Images** - Support for ECR-based Lambda deployments
- **ARM64 Support** - Graviton2 processor for cost savings
- **Auto-Packaging** - Automatic ZIP creation from source directory
- **IAM Management** - Automatic role creation with customizable policies
- **VPC Integration** - Deploy Lambda in private subnets
- **Function URLs** - HTTP endpoints without API Gateway
- **Event Sources** - SQS, DynamoDB Streams, Kinesis, etc.
- **X-Ray Tracing** - Distributed tracing support
- **CloudWatch Logs** - Automatic log group with retention
- **Provisioned Concurrency** - Consistent cold start times
- **SnapStart** - Fast startup for Java functions
- **Dead Letter Queues** - Failed invocation handling

## Usage

### Basic Python Function

```hcl
module "lambda" {
  source = "ogulcanaydogan/lambda/aws"

  function_name = "my-python-function"
  description   = "My Python Lambda function"
  runtime       = "python3.12"
  handler       = "main.handler"

  source_path = "./src"

  environment_variables = {
    LOG_LEVEL = "INFO"
  }

  tags = {
    Environment = "production"
  }
}
```

### Node.js Function with VPC

```hcl
module "lambda" {
  source = "ogulcanaydogan/lambda/aws"

  function_name = "api-handler"
  runtime       = "nodejs20.x"
  handler       = "index.handler"

  source_path = "./api"

  memory_size = 256
  timeout     = 30

  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment_variables = {
    DB_HOST     = module.rds.endpoint
    DB_NAME     = "myapp"
    STAGE       = "production"
  }

  tags = {
    Environment = "production"
  }
}
```

### Function with Custom IAM Policies

```hcl
module "lambda" {
  source = "ogulcanaydogan/lambda/aws"

  function_name = "s3-processor"
  runtime       = "python3.12"
  handler       = "processor.handler"

  source_path = "./processor"

  policy_statements = [
    {
      sid     = "S3Access"
      actions = ["s3:GetObject", "s3:PutObject"]
      resources = [
        "arn:aws:s3:::my-bucket/*"
      ]
    },
    {
      sid     = "DynamoDBAccess"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ]
      resources = [
        aws_dynamodb_table.main.arn
      ]
    }
  ]

  tags = {
    Environment = "production"
  }
}
```

### Function with SQS Event Source

```hcl
module "lambda" {
  source = "ogulcanaydogan/lambda/aws"

  function_name = "sqs-consumer"
  runtime       = "python3.12"
  handler       = "consumer.handler"

  source_path = "./consumer"

  timeout = 60

  event_source_mappings = {
    sqs = {
      event_source_arn = aws_sqs_queue.main.arn
      batch_size       = 10
      maximum_batching_window_in_seconds = 5

      filter_criteria = {
        filters = [
          {
            pattern = jsonencode({
              body = {
                type = ["order"]
              }
            })
          }
        ]
      }

      scaling_config = {
        maximum_concurrency = 50
      }
    }
  }

  tags = {
    Environment = "production"
  }
}
```

### Function with DynamoDB Streams

```hcl
module "lambda" {
  source = "ogulcanaydogan/lambda/aws"

  function_name = "dynamodb-processor"
  runtime       = "nodejs20.x"
  handler       = "stream.handler"

  source_path = "./stream-handler"

  event_source_mappings = {
    dynamodb = {
      event_source_arn       = aws_dynamodb_table.main.stream_arn
      starting_position      = "LATEST"
      batch_size             = 100
      parallelization_factor = 10

      destination_config = {
        on_failure = {
          destination_arn = aws_sqs_queue.dlq.arn
        }
      }
    }
  }

  tags = {
    Environment = "production"
  }
}
```

### Function URL (HTTP Endpoint)

```hcl
module "lambda" {
  source = "ogulcanaydogan/lambda/aws"

  function_name = "webhook-handler"
  runtime       = "python3.12"
  handler       = "webhook.handler"

  source_path = "./webhook"

  create_function_url           = true
  function_url_authorization_type = "NONE"

  function_url_cors = {
    allow_origins     = ["https://myapp.com"]
    allow_methods     = ["POST"]
    allow_headers     = ["content-type", "authorization"]
    allow_credentials = true
    max_age           = 86400
  }

  tags = {
    Environment = "production"
  }
}
```

### Container Image Lambda

```hcl
module "lambda" {
  source = "ogulcanaydogan/lambda/aws"

  function_name = "container-function"
  package_type  = "Image"

  image_uri = "${aws_ecr_repository.lambda.repository_url}:latest"

  memory_size = 1024
  timeout     = 300

  architectures = ["arm64"]  # Graviton2

  tags = {
    Environment = "production"
  }
}
```

### Java Function with SnapStart

```hcl
module "lambda" {
  source = "ogulcanaydogan/lambda/aws"

  function_name = "java-function"
  runtime       = "java21"
  handler       = "com.example.Handler::handleRequest"

  filename = "./target/function.jar"

  memory_size = 512
  timeout     = 30

  snap_start = true  # Enable SnapStart for faster cold starts

  tags = {
    Environment = "production"
  }
}
```

### Function with X-Ray Tracing

```hcl
module "lambda" {
  source = "ogulcanaydogan/lambda/aws"

  function_name = "traced-function"
  runtime       = "python3.12"
  handler       = "main.handler"

  source_path = "./src"

  tracing_mode = "Active"

  tags = {
    Environment = "production"
  }
}
```

### Function with Provisioned Concurrency

```hcl
module "lambda" {
  source = "ogulcanaydogan/lambda/aws"

  function_name = "fast-function"
  runtime       = "python3.12"
  handler       = "main.handler"

  source_path = "./src"

  provisioned_concurrent_executions = 10

  tags = {
    Environment = "production"
  }
}
```

### Function with API Gateway Trigger

```hcl
module "lambda" {
  source = "ogulcanaydogan/lambda/aws"

  function_name = "api-backend"
  runtime       = "python3.12"
  handler       = "api.handler"

  source_path = "./api"

  allowed_triggers = {
    api_gateway = {
      principal  = "apigateway.amazonaws.com"
      source_arn = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
    }
  }

  tags = {
    Environment = "production"
  }
}
```

### Function with S3 Trigger

```hcl
module "lambda" {
  source = "ogulcanaydogan/lambda/aws"

  function_name = "s3-trigger"
  runtime       = "python3.12"
  handler       = "processor.handler"

  source_path = "./processor"

  allowed_triggers = {
    s3 = {
      principal  = "s3.amazonaws.com"
      source_arn = aws_s3_bucket.uploads.arn
    }
  }

  policy_statements = [
    {
      actions   = ["s3:GetObject"]
      resources = ["${aws_s3_bucket.uploads.arn}/*"]
    }
  ]

  tags = {
    Environment = "production"
  }
}
```

### Graviton2 (ARM64) Function

```hcl
module "lambda" {
  source = "ogulcanaydogan/lambda/aws"

  function_name = "arm-function"
  runtime       = "python3.12"
  handler       = "main.handler"

  source_path = "./src"

  architectures = ["arm64"]  # Up to 34% better price-performance

  tags = {
    Environment = "production"
  }
}
```

## Inputs

### Required

| Name | Description | Type |
|------|-------------|------|
| `function_name` | Lambda function name | `string` |

### Code Source (one required)

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `source_path` | Path to source directory (auto-zipped) | `string` | `null` |
| `filename` | Path to deployment ZIP file | `string` | `null` |
| `s3_bucket` | S3 bucket with deployment package | `string` | `null` |
| `s3_key` | S3 key of deployment package | `string` | `null` |
| `image_uri` | ECR image URI (for container Lambda) | `string` | `null` |

### Runtime Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `runtime` | Lambda runtime | `string` | `"python3.12"` |
| `handler` | Function entrypoint | `string` | `"index.handler"` |
| `package_type` | Deployment type (Zip, Image) | `string` | `"Zip"` |
| `architectures` | Instruction set (x86_64, arm64) | `list(string)` | `["x86_64"]` |

### Performance

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `memory_size` | Memory in MB (128-10240) | `number` | `128` |
| `timeout` | Timeout in seconds (1-900) | `number` | `30` |
| `ephemeral_storage_size` | Ephemeral storage in MB | `number` | `512` |
| `reserved_concurrent_executions` | Reserved concurrency (-1 unlimited) | `number` | `-1` |
| `provisioned_concurrent_executions` | Provisioned concurrency | `number` | `null` |

### VPC

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `vpc_config` | VPC configuration | `object` | `null` |

### IAM

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `create_role` | Create IAM role | `bool` | `true` |
| `role_arn` | Existing role ARN | `string` | `null` |
| `policy_statements` | Custom IAM statements | `list(object)` | `[]` |
| `attach_policy_arns` | Policy ARNs to attach | `list(string)` | `[]` |

### Environment

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `environment_variables` | Environment variables | `map(string)` | `{}` |
| `layers` | Lambda layer ARNs (max 5) | `list(string)` | `[]` |

### Observability

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `tracing_mode` | X-Ray tracing (Active, PassThrough) | `string` | `null` |
| `cloudwatch_logs_retention_days` | Log retention days | `number` | `14` |

### Function URL

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `create_function_url` | Create Function URL | `bool` | `false` |
| `function_url_authorization_type` | Auth type (NONE, AWS_IAM) | `string` | `"NONE"` |
| `function_url_cors` | CORS configuration | `object` | `null` |

### Event Sources

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `event_source_mappings` | Event source mappings | `map(object)` | `{}` |
| `allowed_triggers` | Allowed trigger permissions | `map(object)` | `{}` |

### Other

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `dead_letter_target_arn` | DLQ SNS/SQS ARN | `string` | `null` |
| `publish` | Publish new version | `bool` | `false` |
| `aliases` | Lambda aliases | `map(object)` | `{}` |
| `snap_start` | Enable SnapStart (Java) | `bool` | `false` |
| `tags` | Resource tags | `map(string)` | `{}` |

## Outputs

### Function

| Name | Description |
|------|-------------|
| `function_name` | Function name |
| `function_arn` | Function ARN |
| `function_qualified_arn` | Qualified ARN (with version) |
| `function_invoke_arn` | Invoke ARN (for API Gateway) |
| `function_version` | Published version |

### IAM

| Name | Description |
|------|-------------|
| `role_name` | IAM role name |
| `role_arn` | IAM role ARN |

### Logs

| Name | Description |
|------|-------------|
| `cloudwatch_log_group_name` | Log group name |
| `cloudwatch_log_group_arn` | Log group ARN |

### Function URL

| Name | Description |
|------|-------------|
| `function_url` | Function URL endpoint |

### Utilities

| Name | Description |
|------|-------------|
| `invoke_command` | AWS CLI invoke command |
| `logs_command` | AWS CLI logs command |

## Supported Runtimes

- Python: `python3.9`, `python3.10`, `python3.11`, `python3.12`
- Node.js: `nodejs18.x`, `nodejs20.x`
- Java: `java11`, `java17`, `java21`
- .NET: `dotnet6`, `dotnet8`
- Ruby: `ruby3.2`, `ruby3.3`
- Go: `go1.x`
- Custom: `provided`, `provided.al2`, `provided.al2023`

## Examples

See [`examples/`](./examples/) for complete configurations.
