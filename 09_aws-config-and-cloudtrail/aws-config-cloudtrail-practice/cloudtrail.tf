# 고유한 ID를 생성하여 리소스 이름에 사용
resource "random_integer" "uid" {
  max = 9999
  min = 1000
}

# CloudTrail 로그를 저장할 S3 버킷 생성, 고유한 이름을 사용
resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket        = "my-cloudtrail-logs-bucket-${random_integer.uid.result}" # 랜덤 ID를 포함한 고유한 버킷 이름 생성
  force_destroy = true
  tags = {
    Name = "CloudTrailLogsBucket"
  }
}

# S3 버킷에 대한 퍼블릭 액세스 차단 설정, 보안을 위해 퍼블릭 액세스 차단
resource "aws_s3_bucket_public_access_block" "cloudtrail_bucket_public_access_block" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id

  block_public_acls       = true # 퍼블릭 ACL을 차단
  block_public_policy     = true # 퍼블릭 정책을 차단
  ignore_public_acls      = true # 퍼블릭 ACL을 무시
  restrict_public_buckets = true # 퍼블릭 버킷을 제한
}

# S3 버킷 버전 관리 활성화, 로그 보존을 위해 버전 관리 활성화
resource "aws_s3_bucket_versioning" "cloudtrail_bucket_versioning" {
  bucket = aws_s3_bucket.cloudtrail_bucket.bucket

  versioning_configuration {
    status = "Enabled" # 버전 관리 활성화
  }
}

# S3 버킷에 대한 서버 측 암호화 설정, kms 암호화를 사용하여 보안 강화
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_bucket_sse" {
  bucket = aws_s3_bucket.cloudtrail_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"                  # KMS 암호화 방식 지정
      kms_master_key_id = aws_kms_key.s3_kms_key.arn # 생성한 KMS 키 ARN 연결
    }
  }
}


# 현재 계정 정보를 가져오는 데이터 소스
# 현재 AWS 계정 ID, ARN, 사용자 정보를 가져옴
#data "aws_caller_identity" "current" {}

locals {
  my_cloudtrail = "my-cloudtrail"
  region        = "us-east-1"
}

resource "aws_kms_key" "s3_kms_key" {
  description             = "S3 버킷 암호화용 KMS 키"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "cloudtrail-key-policy",
    Statement = [
      # 필수: 키 정책 관리 권한 추가 
      {
        Sid    = "EnableRootAndDeployerAccess",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      # CloudTrail 접근 권한 (기존 정책 보강)
      {
        Sid    = "EnableCloudTrailAccess",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        Resource = "*",
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cloudtrail:${local.region}:${data.aws_caller_identity.current.account_id}:trail/${local.my_cloudtrail}"
          }
        }
      }
    ]
  })
}


# CloudTrail 로그 저장을 위한 S3 버킷 정책 설정
resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service : "cloudtrail.amazonaws.com"
        },
        Action   = "s3:PutObject", # CloudTrail이 S3에 로그 파일을 업로드할 수 있도록 허용
        Resource = "${aws_s3_bucket.cloudtrail_bucket.arn}/*",
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" : "bucket-owner-full-control" # 버킷 소유자가 업로드된 객체에 대한 전체 제어권을 가짐
          }
        }
      },
      {
        Effect = "Allow",
        Principal = {
          Service : "cloudtrail.amazonaws.com"
        },
        Action   = "s3:GetBucketAcl", # CloudTrail이 버킷의 ACL을 조회할 수 있도록 허용
        Resource = aws_s3_bucket.cloudtrail_bucket.arn
      }
    ]
  })
}

# CloudWatch 로그 그룹 생성, 로그 보존 기간을 1년으로 설정
resource "aws_cloudwatch_log_group" "cloudtrail_log_group" {
  name              = "/aws/cloudtrail/logs-${random_integer.uid.id}"
  retention_in_days = 365 # 보존 기간 1년 설정

  tags = {
    Name = "CloudTrailLogGroup"
  }
}

# CloudTrail이 CloudWatch에 로그를 전송할 수 있도록 IAM 역할 생성
resource "aws_iam_role" "cloudtrail_role" {
  name = "cloudtrail-role-${random_integer.uid.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      },
      Action = "sts:AssumeRole" # CloudTrail이 역할을 수임할 수 있도록 허용
    }]
  })
}

# CloudWatch 로그 전송을 위한 IAM 역할 정책 연결
resource "aws_iam_role_policy" "cloudtrail_policy" {
  name = "cloudtrail-policy"
  role = aws_iam_role.cloudtrail_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents" # 로그 스트림 생성 및 로그 전송을 허용
      ],
      Resource = "${aws_cloudwatch_log_group.cloudtrail_log_group.arn}:*" # 로그 그룹 ARN에 대한 권한 설정
    }]
  })
}

# CloudTrail 설정, 로그 파일 무결성 검증 활성화
resource "aws_cloudtrail" "main" {
  name                          = local.my_cloudtrail
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket.bucket
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail_log_group.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_role.arn
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  enable_log_file_validation    = true # 로그 파일 무결성 검증 활성화

  event_selector {
    read_write_type           = "All" # 모든 읽기/쓰기 이벤트를 추적
    include_management_events = true  # 관리 이벤트를 포함
  }

  tags = {
    Name = "MainCloudTrail"
  }
}

# s3 변경 감지 규칙
resource "aws_cloudwatch_event_rule" "s3_bucket_policy_change" {
  name        = "S3BucketPolicyChange"
  description = "Triggered when S3 bucket policy changes."
  event_pattern = jsonencode({
    "source" : ["aws.s3"],
    "detail-type" : ["AWS API Call via CloudTrail"],
    "detail" : {
      "eventName" : [
        "PutBucketPolicy",
        "DeleteBucketPolicy"
      ]
    }
  })
}

# IAM 권한 변경 감지 규칙
resource "aws_cloudwatch_event_rule" "iam_permission_change" {
  name        = "IAMPermissionChange"
  description = "Triggered when IAM permission changes (e.g., Attach/Detach Role Policy)."
  event_pattern = jsonencode({
    "source" : ["aws.iam"],
    "detail-type" : ["AWS API Call via CloudTrail"],
    "detail" : {
      "eventName" : [
        "PutRolePolicy",
        "DeleteRolePolicy",
        "AttachRolePolicy",
        "DetachRolePolicy",
        "PutUserPolicy",
        "DeleteUserPolicy",
        "AttachUserPolicy",
        "DetachUserPolicy"
      ]
    }
  })
}

# CloudTrail 이벤트를 기반으로 설정된 CloudWatch 이벤트 규칙
resource "aws_cloudwatch_event_target" "target_iam_change" {
  rule      = aws_cloudwatch_event_rule.iam_permission_change.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.cloudtrail_sns_topic.arn
}

resource "aws_cloudwatch_event_target" "target_s3_policy_change" {
  rule      = aws_cloudwatch_event_rule.s3_bucket_policy_change.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.cloudtrail_sns_topic.arn
}

resource "aws_sns_topic_policy" "cloudtrail_sns_topic_policy" {
  arn = aws_sns_topic.cloudtrail_sns_topic.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchEventsToPublishToSNS"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.cloudtrail_sns_topic.arn
      }
    ]
  })
}


# SNS 주제 생성, 경고 알림을 위한 SNS 주제
resource "aws_sns_topic" "cloudtrail_sns_topic" {
  name = "cloudtrail-alerts-topic"
}

# SNS 이메일 구독 설정
resource "aws_sns_topic_subscription" "cloudtrail_email_subscription" {
  topic_arn = aws_sns_topic.cloudtrail_sns_topic.arn
  protocol  = "email"
  endpoint  = "ilsunchoi@cloudsecuritylab.co.kr" # 알림을 받을 이메일 주소
}
