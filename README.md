# terraform-aws-intermediate

## 개요
이 저장소는 AWS 중급 학습자를 위해 구성된 Terraform 실습 모음입니다. 각 번호가 붙은 디렉터리는 네트워킹, 서버리스, 데이터베이스, IAM, 모니터링 등 특정 주제를 다루는 시나리오별 모듈을 포함하며 독립적으로 배포해 인프라 자동화를 연습할 수 있습니다.

## 준비 사항
- 로컬에 Terraform CLI 1.5+와 AWS CLI 2.x 설치
- 실습용 AWS 계정 및 자격 증명 설정 (`aws configure`, 환경 변수, 프로파일 등)
- 팀과 버전을 맞추고 싶다면 `tfenv` 같은 Terraform 버전 관리 도구

## 저장소 구조
- `01_terraform-aws-config` — VPC, EC2, 상태 파일 관리 기초
- `02_aws-serverless-services-using-terraform` — Lambda, API Gateway, Route 53, 정적 웹 호스팅 실습
- `03_elb-asg-terraform` — Auto Scaling Group과 로드 밸런서 패턴, Packer 연계
- `04_db-service-management` — RDS, Aurora, DynamoDB, Redis 운영 시나리오
- `05_wordpress` — WordPress 기준 배포 예제
- `06_terraform_visualization` — Terraform 계획을 시각화하는 예제
- `07_iam-user-and-policy-management` — IAM 사용자 및 정책, IAM Identity Center 실습
- `08_aws-secret-management` — KMS와 Secrets Manager 구성
- `09_aws-config-and-cloudtrail` — AWS Config와 CloudTrail 로그 수집 시나리오

각 시나리오 디렉터리는 자체 `main.tf`, 변수 파일, 선택적 `terraform.tfvars`를 갖춘 Terraform 루트 모듈입니다. 새 실습을 추가할 때는 번호 체계(`10_new-topic/...`)를 따라 주세요.

## 시나리오 실행 절차
1. 목표 시나리오 디렉터리로 이동합니다.
2. `terraform init`으로 필요한 프로바이더와 모듈을 다운로드합니다.
3. `terraform.tfvars` 또는 `-var` 플래그로 변수를 조정합니다.
4. `terraform plan -out=plan.tfplan`을 실행해 변경 사항을 검토합니다.
5. `terraform apply plan.tfplan`으로 배포하고 결과를 확인합니다.
6. 실습 종료 시 `terraform destroy`로 리소스를 반드시 정리합니다.

## 개발 및 검증 명령어
- `terraform fmt -recursive` — 전체 Terraform 파일 포맷 정리
- `terraform validate` — 구문 및 변수 정의 검증
- `terraform plan` — 변경 사항 미리보기 및 PR 공유용 출력 확보
- `terraform graph | dot -Tpng > graph.png` — (선택) 모듈 의존성 시각화

## 기여 방법
네이밍 규칙, 커밋 메시지, PR 작성 요령은 `AGENTS.md`를 참고하세요. PR을 올릴 때는 관련 시나리오 경로와 `terraform plan` 또는 `apply` 출력 요약을 포함하고, 수동 확인이 필요한 사항은 시나리오별 문서에 기록합니다.

## 정리 및 안전 수칙
대부분의 실습은 과금되는 AWS 리소스를 생성합니다. 실습 후 `terraform destroy`로 스택을 제거하고, AWS 콘솔에서 잔존 리소스가 없는지 확인하세요. 가능하면 교육 전용 계정을 사용해 운영 환경과 충돌하지 않도록 합니다.
