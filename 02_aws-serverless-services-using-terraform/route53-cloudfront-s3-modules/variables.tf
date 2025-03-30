variable "aws_region" {
  description = "AWS 리전"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI 프로파일"
  type        = string
}

variable "bucket_name" {
  description = "S3 버킷의 기본 이름"
  type        = string
}

variable "environment" {
  description = "환경 설정 (dev 또는 prod)"
  type        = string
}

variable "index_document" {
  description = "정적 웹사이트 인덱스 문서"
  type        = string
}

variable "error_document" {
  description = "정적 웹사이트 에러 문서"
  type        = string
}

variable "index_document_path" {
  description = "로컬의 인덱스 문서 경로"
  type        = string
}

variable "error_document_path" {
  description = "로컬의 에러 문서 경로"
  type        = string
}

variable "private_dns_name" {
  description = "Private DNS 도메인 이름"
  type        = string
}

variable "ami_id" {
  description = "EC2 인스턴스에 사용할 AMI ID"
  type        = string
}

variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
}

variable "pub_key_file_path" {
  description = "공개 키 위치 정보"
  type        = string
}

variable "vpc_name" {
  description = "사용할 vpc 이름"
  type        = string
}

variable "vpc_cidr_block" {
  description = "vpc에 사용할 CIDR 블록 (예: 10.0.0.0/16)"
  type        = string
}

variable "public_subnet_cidr" {
  description = "subnet에 사용할 CIDR 블록 (예: 10.0.0.0/24)"
  type        = string
}

variable "subnet_availability_zone" {
  description = "subnet AZ 위치(예: us-east-1a)"
  type        = string
}

