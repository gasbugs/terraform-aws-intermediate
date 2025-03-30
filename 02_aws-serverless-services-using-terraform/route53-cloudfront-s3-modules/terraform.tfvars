# AWS 설정
aws_region  = "us-east-1"  # 배포할 AWS 리전
aws_profile = "my-profile" # 사용할 AWS CLI 프로파일

# S3 버킷 설정
bucket_name = "my-static-site" # S3 버킷 기본 이름
environment = "dev"            # 환경 (예: dev, prod)

# S3 웹사이트 설정
index_document      = "index.html"       # 정적 웹사이트의 인덱스 파일
error_document      = "error.html"       # 정적 웹사이트의 에러 페이지 파일
index_document_path = "files/index.html" # 로컬에서 인덱스 파일 경로
error_document_path = "files/error.html" # 로컬에서 에러 파일 경로

# Route53 및 EC2 설정
private_dns_name         = "test.private.example.com"
ami_id                   = "ami-0ebfd941bbafe70c6" # Amazon Linux 2023 AMI (리전을 확인하여 변경 필요)
instance_type            = "t2.micro"
pub_key_file_path        = "c:/users/isc03/.ssh/my-key.pub"
vpc_name                 = "private-dns-test-vpc"
vpc_cidr_block           = "10.0.0.0/16"
public_subnet_cidr       = "10.0.0.0/24"
subnet_availability_zone = "us-east-1a"
