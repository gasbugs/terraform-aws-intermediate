######################################
# AWS Config와 Config 로그 저장용 S3 구성
# config 저장용 S3 버킷 생성
# AWS Config 로그를 저장할 S3 버킷을 생성하고, 리소스가 삭제될 때 버킷도 삭제되도록 force_destroy 옵션 설정
resource "aws_s3_bucket" "config_bucket" {
  bucket        = "example-awsconfig-${random_integer.uid.result}"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "config_bucket_policy" {
  bucket = aws_s3_bucket.config_bucket.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "config.amazonaws.com"
        },
        "Action" : [
          "s3:GetBucketAcl",
          "s3:PutObject"
        ],
        "Resource" : [
          "${aws_s3_bucket.config_bucket.arn}",
          "${aws_s3_bucket.config_bucket.arn}/*"
        ]
      }
    ]
  })
}

######################################
# Config Recorder 활성화
# Configuration Recorder를 활성화하여 AWS 리소스 상태 추적 시작
resource "aws_config_configuration_recorder_status" "recorder_status" {
  name       = aws_config_configuration_recorder.my_config_recoder.name
  is_enabled = true                                                     # 레코더 활성화
  depends_on = [aws_config_delivery_channel.my_config_delivery_channel] # Delivery Channel이 먼저 설정된 후 실행
}

# 현재 계정 정보를 가져오는 데이터 소스
# 현재 AWS 계정 ID, ARN, 사용자 정보를 가져옴
data "aws_caller_identity" "current" {}

# 현재 계정의 ConfigRole을 가져와서 Recorder에 권한 부여 
# AWS Config가 리소스 상태를 기록할 수 있도록 권한 부여
resource "aws_config_configuration_recorder" "my_config_recoder" {
  name     = "example"
  role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/config.amazonaws.com/AWSServiceRoleForConfig" # AWS 관리형 Role

  recording_group {
    all_supported                 = true # 모든 지원 리소스 기록
    include_global_resource_types = true # 글로벌 리소스도 포함
  }
}

# SNS 토픽 생성, AWS Config 알림을 받을 수 있도록 설정
# Config 이벤트에 대한 알림을 받을 수 있는 SNS 토픽 생성
resource "aws_sns_topic" "config_topic" {
  name = "config-topic-${random_integer.uid.result}"
}

# SNS 이메일 구독 설정
resource "aws_sns_topic_subscription" "config_email_subscription" {
  topic_arn = aws_sns_topic.config_topic.arn
  protocol  = "email"
  endpoint  = "ilsunchoi@cloudsecuritylab.co.kr" # 알림을 받을 이메일 주소
}


# AWS Config 전송 채널 생성
# 구성 변경 데이터를 S3 버킷과 SNS 토픽으로 전송할 채널을 생성
resource "aws_config_delivery_channel" "my_config_delivery_channel" {
  name           = "my_config_delivery_channel"
  s3_bucket_name = aws_s3_bucket.config_bucket.bucket                    # S3 버킷으로 로그 저장
  sns_topic_arn  = aws_sns_topic.config_topic.arn                        # SNS 알림을 통해 통지
  depends_on     = [aws_config_configuration_recorder.my_config_recoder] # Recorder 설정 완료 후 실행
}

#########################################
# 규칙 및 규정 준수팩 추가
# AWS Config 규칙 설정 (예: S3 버킷에 대한 퍼블릭 읽기 금지)
# S3 버킷에 대한 퍼블릭 읽기 액세스가 금지되었는지 평가하는 규칙 설정
resource "aws_config_config_rule" "s3_bucket_public_read_prohibited" {
  name = "s3-bucket-public-read-prohibited"
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }
  depends_on = [aws_config_configuration_recorder_status.recorder_status]
}

resource "aws_config_config_rule" "s3_bucket_public_write_prohibited" {
  name = "s3-bucket-public-write-prohibited"
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }
  depends_on = [aws_config_configuration_recorder_status.recorder_status]
}

######################################
# EventBridge (CloudWatch Events) 규칙 생성:
resource "aws_cloudwatch_event_rule" "config_non_compliant_rule" {
  name        = "capture-aws-config-non-compliant"
  description = "Capture AWS Config non-compliant resources"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      messageType = ["ComplianceChangeNotification"]
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })
}

# zip 파일 생성
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/index.js"
  output_path = "${path.module}/function.zip"
}

# Lambda 함수 생성 (실시간 알림 처리):
resource "aws_lambda_function" "config_non_compliant_handler" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "config_non_compliant_handler"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"

  # Lambda 함수 코드는 별도로 작성하여 zip 파일로 패키징해야 합니다.
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.config_topic.arn
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.config_non_compliant_handler.function_name}"
  retention_in_days = 14 # 로그 보존 기간을 14일로 설정 (필요에 따라 조정 가능)
}

# EventBridge 규칙과 Lambda 함수 연결:
resource "aws_cloudwatch_event_target" "config_non_compliant_target" {
  rule      = aws_cloudwatch_event_rule.config_non_compliant_rule.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.config_non_compliant_handler.arn
}

# Lambda 함수에 필요한 IAM 역할 및 정책 설정:
resource "aws_iam_role" "lambda_role" {
  name = "config_non_compliant_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name = "lambda_permissions"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.config_topic.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/*"
      }
    ]
  })
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.config_non_compliant_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.config_non_compliant_rule.arn
}
