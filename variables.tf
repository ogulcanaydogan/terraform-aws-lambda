variable "function_name" {
  description = "Name of the Lambda function."
  type        = string

  validation {
    condition     = length(trimspace(var.function_name)) > 0 && length(var.function_name) <= 64
    error_message = "function_name must be between 1 and 64 characters."
  }

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.function_name))
    error_message = "function_name can only contain letters, numbers, hyphens, and underscores."
  }
}

variable "description" {
  description = "Description of the Lambda function."
  type        = string
  default     = ""
}

variable "runtime" {
  description = "Lambda runtime (e.g., python3.12, nodejs20.x, java21)."
  type        = string
  default     = "python3.12"

  validation {
    condition     = can(regex("^(python3\\.(9|10|11|12)|nodejs(18|20)\\.x|java(11|17|21)|dotnet(6|8)|ruby3\\.(2|3)|go1\\.x|provided(\\.al2023?)?)$", var.runtime))
    error_message = "runtime must be a valid Lambda runtime."
  }
}

variable "handler" {
  description = "Function entrypoint (e.g., index.handler)."
  type        = string
  default     = "index.handler"
}

variable "architectures" {
  description = "Instruction set architecture (x86_64 or arm64)."
  type        = list(string)
  default     = ["x86_64"]

  validation {
    condition     = length(var.architectures) == 1 && contains(["x86_64", "arm64"], var.architectures[0])
    error_message = "architectures must be [\"x86_64\"] or [\"arm64\"]."
  }
}

# Code Source
variable "source_path" {
  description = "Path to the Lambda source code directory or file."
  type        = string
  default     = null
}

variable "filename" {
  description = "Path to the deployment package zip file."
  type        = string
  default     = null
}

variable "s3_bucket" {
  description = "S3 bucket containing the deployment package."
  type        = string
  default     = null
}

variable "s3_key" {
  description = "S3 key of the deployment package."
  type        = string
  default     = null
}

variable "s3_object_version" {
  description = "S3 object version of the deployment package."
  type        = string
  default     = null
}

variable "image_uri" {
  description = "ECR image URI for container-based Lambda."
  type        = string
  default     = null
}

variable "package_type" {
  description = "Lambda deployment package type (Zip or Image)."
  type        = string
  default     = "Zip"

  validation {
    condition     = contains(["Zip", "Image"], var.package_type)
    error_message = "package_type must be Zip or Image."
  }
}

# Memory and Timeout
variable "memory_size" {
  description = "Amount of memory in MB (128-10240)."
  type        = number
  default     = 128

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "memory_size must be between 128 and 10240 MB."
  }
}

variable "timeout" {
  description = "Function timeout in seconds (1-900)."
  type        = number
  default     = 30

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "timeout must be between 1 and 900 seconds."
  }
}

variable "ephemeral_storage_size" {
  description = "Ephemeral storage size in MB (512-10240)."
  type        = number
  default     = 512

  validation {
    condition     = var.ephemeral_storage_size >= 512 && var.ephemeral_storage_size <= 10240
    error_message = "ephemeral_storage_size must be between 512 and 10240 MB."
  }
}

# Environment Variables
variable "environment_variables" {
  description = "Environment variables for the Lambda function."
  type        = map(string)
  default     = {}
  sensitive   = true
}

# VPC Configuration
variable "vpc_config" {
  description = "VPC configuration for the Lambda function."
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

# IAM
variable "create_role" {
  description = "Create a new IAM role for the Lambda function."
  type        = bool
  default     = true
}

variable "role_arn" {
  description = "ARN of an existing IAM role (when create_role is false)."
  type        = string
  default     = null
}

variable "policy_statements" {
  description = "IAM policy statements to attach to the Lambda role."
  type = list(object({
    sid       = optional(string)
    effect    = optional(string, "Allow")
    actions   = list(string)
    resources = list(string)
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))
  default = []
}

variable "attach_policy_arns" {
  description = "List of IAM policy ARNs to attach to the Lambda role."
  type        = list(string)
  default     = []
}

variable "attach_network_policy" {
  description = "Attach AWSLambdaVPCAccessExecutionRole policy (auto-attached when vpc_config is set)."
  type        = bool
  default     = null
}

# Layers
variable "layers" {
  description = "List of Lambda layer ARNs."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.layers) <= 5
    error_message = "Maximum 5 layers can be attached to a Lambda function."
  }
}

# Tracing
variable "tracing_mode" {
  description = "X-Ray tracing mode (Active or PassThrough)."
  type        = string
  default     = null

  validation {
    condition     = var.tracing_mode == null || contains(["Active", "PassThrough"], var.tracing_mode)
    error_message = "tracing_mode must be Active or PassThrough."
  }
}

# Dead Letter Queue
variable "dead_letter_target_arn" {
  description = "ARN of SNS topic or SQS queue for dead letter queue."
  type        = string
  default     = null
}

# Reserved Concurrency
variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions (-1 for unreserved)."
  type        = number
  default     = -1

  validation {
    condition     = var.reserved_concurrent_executions >= -1
    error_message = "reserved_concurrent_executions must be -1 or greater."
  }
}

# Provisioned Concurrency
variable "provisioned_concurrent_executions" {
  description = "Provisioned concurrent executions."
  type        = number
  default     = null

  validation {
    condition     = var.provisioned_concurrent_executions == null || var.provisioned_concurrent_executions > 0
    error_message = "provisioned_concurrent_executions must be greater than 0."
  }
}

# CloudWatch Logs
variable "cloudwatch_logs_retention_days" {
  description = "CloudWatch Logs retention in days."
  type        = number
  default     = 14

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.cloudwatch_logs_retention_days)
    error_message = "cloudwatch_logs_retention_days must be a valid CloudWatch Logs retention value."
  }
}

variable "cloudwatch_logs_kms_key_id" {
  description = "KMS key ID for CloudWatch Logs encryption."
  type        = string
  default     = null
}

# Function URL
variable "create_function_url" {
  description = "Create a Lambda Function URL."
  type        = bool
  default     = false
}

variable "function_url_authorization_type" {
  description = "Function URL authorization type (NONE or AWS_IAM)."
  type        = string
  default     = "NONE"

  validation {
    condition     = contains(["NONE", "AWS_IAM"], var.function_url_authorization_type)
    error_message = "function_url_authorization_type must be NONE or AWS_IAM."
  }
}

variable "function_url_cors" {
  description = "CORS configuration for Function URL."
  type = object({
    allow_credentials = optional(bool, false)
    allow_headers     = optional(list(string), ["*"])
    allow_methods     = optional(list(string), ["*"])
    allow_origins     = optional(list(string), ["*"])
    expose_headers    = optional(list(string), [])
    max_age           = optional(number, 0)
  })
  default = null
}

# Event Source Mappings
variable "event_source_mappings" {
  description = "Map of event source mappings."
  type = map(object({
    event_source_arn                   = string
    batch_size                         = optional(number, 10)
    maximum_batching_window_in_seconds = optional(number, 0)
    enabled                            = optional(bool, true)
    starting_position                  = optional(string)
    starting_position_timestamp        = optional(string)
    parallelization_factor             = optional(number)
    maximum_record_age_in_seconds      = optional(number)
    bisect_batch_on_function_error     = optional(bool)
    maximum_retry_attempts             = optional(number)
    tumbling_window_in_seconds         = optional(number)

    filter_criteria = optional(object({
      filters = list(object({
        pattern = string
      }))
    }))

    destination_config = optional(object({
      on_failure = object({
        destination_arn = string
      })
    }))

    scaling_config = optional(object({
      maximum_concurrency = number
    }))
  }))
  default = {}
}

# Permissions
variable "allowed_triggers" {
  description = "Map of allowed triggers (permissions) for the Lambda function."
  type = map(object({
    principal          = string
    source_arn         = optional(string)
    source_account     = optional(string)
    event_source_token = optional(string)
  }))
  default = {}
}

# Publish
variable "publish" {
  description = "Publish a new Lambda version."
  type        = bool
  default     = false
}

# Aliases
variable "aliases" {
  description = "Map of Lambda aliases to create."
  type = map(object({
    description      = optional(string)
    function_version = optional(string)
    routing_config = optional(object({
      additional_version_weights = map(number)
    }))
  }))
  default = {}
}

# SnapStart (Java only)
variable "snap_start" {
  description = "Enable SnapStart for Java runtimes."
  type        = bool
  default     = false
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
