######################################
# AWS Config와 Config 로그 저장용 S3 구성
# 고유한 ID를 생성하여 리소스 이름에 사용
# 1000에서 9999 사이의 임의의 숫자를 생성하여 리소스 이름에 추가
resource "random_integer" "uid" {
  max = 9999
  min = 1000
}

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

# EC2 인스턴스에 퍼블릭 IP가 설정되지 않도록 검증하는 규칙 설정
resource "aws_config_config_rule" "ec2_instance_no_public_ip" {
  name = "ec2-instance-no-public-ip"
  source {
    owner             = "AWS"
    source_identifier = "EC2_INSTANCE_NO_PUBLIC_IP"
  }
  depends_on = [aws_config_configuration_recorder_status.recorder_status]

}

# K-ISMS 규정 준수 팩 예시
# K-ISMS 규정에 맞는 설정을 검증하는 규정 준수 팩을 적용
resource "aws_config_conformance_pack" "kisms_conformance_pack" {
  name = "KISMS-Conformance-Pack"

  delivery_s3_bucket = aws_s3_bucket.config_bucket.bucket                # 규정 준수 결과를 저장할 S3 버킷
  template_body      = file("Operational-Best-Practices-for-KISMS.yaml") # KISMS 관련 규정 준수 팩의 YAML 파일 경로
  depends_on         = [aws_config_configuration_recorder_status.recorder_status]

}
