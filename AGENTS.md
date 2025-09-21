# Repository Guidelines

## 프로젝트 구조 및 모듈 구성
최상위 디렉터리(`01_terraform-aws-config` … `09_aws-config-and-cloudtrail`)는 AWS 영역별 Terraform 실습을 묶어 둡니다. 각 시나리오(예: `03_elb-asg-terraform/asg-elb-infra`)는 `main.tf`, `variables.tf`, `outputs.tf`, 필요 시 `terraform.tfvars` 또는 보조 자산을 포함한 독립 Terraform 루트입니다. 정적 웹 예제는 HTML 파일을 Terraform 정의 옆에 두어 `aws_s3_bucket` 리소스로 바로 업로드할 수 있게 합니다. 새 실습을 추가할 때는 숫자 접두사와 스네이크 케이스(`10_new-topic/example-scenario`)를 따라 목록 순서를 유지하세요.

## 빌드·테스트·개발 명령어
- `terraform fmt -recursive` — 리뷰 전 모든 Terraform 파일을 포맷합니다.
- `terraform init` — 시나리오 디렉터리에서 실행해 프로바이더와 모듈을 내려받습니다.
- `terraform validate` — 구문 오류와 누락된 변수 정의를 빠르게 점검합니다.
- `terraform plan -out=plan.tfplan` — 변경 내역을 검토용으로 저장하고 모듈과 함께 보관합니다.
- `terraform apply plan.tfplan` / `terraform destroy` — 실습 리소스를 배포하거나 제거합니다. 가능하면 별도의 교육용 AWS 계정을 사용하세요.

## 코드 스타일 및 네이밍 규칙
Terraform 기본 들여쓰기(공백 2칸)를 유지하고 할당 연산자를 정렬하세요. 리소스 이름은 소문자-하이픈 패턴(`aws_autoscaling_group.web_asg`)을 사용하며, 변수와 출력은 의미 있는 스네이크 케이스로 작성합니다. 공유 컴포넌트는 `modules/` 하위 디렉터리에 두고 상대 경로로 참조하세요. 공개해도 되는 기본값만 예제 tfvars 파일에 남기고, 비밀 값은 환경 변수나 외부 상태 파일로 관리합니다.

## 테스트 가이드라인
`terraform validate`와 오류 없는 `terraform plan`을 제출 최소 조건으로 삼으세요. AWS 콘솔 확인, 비용 추정 등 수동 검증이 필요하면 시나리오 옆 README에 기록합니다. 백엔드 버킷이나 자격 증명은 샘플 템플릿만 커밋하고 실제 값은 절대 저장소에 올리지 않습니다.

## 커밋 및 PR 가이드라인
커밋 제목은 간결한 현재형으로 작성합니다(`Add ALB listener rule for blue/green`). 기존 이력에는 한국어와 영어가 혼재하지만, 요청이 없다면 영어를 우선합니다. 여러 실습을 수정했다면 커밋 본문에 영향 받은 시나리오 경로를 명시하세요. PR에는 변경 의도, 관련 이슈 링크, 주요 `plan/apply` 출력, 필요한 경우 인프라 확인 스크린샷이나 로그를 첨부해 리뷰어가 빠르게 판단할 수 있도록 합니다.
