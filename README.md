# gcloud-docker-network

[![Shellcheck](https://github.com/sanghaklee-gcloud/gcloud-docker-network/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/sanghaklee-gcloud/gcloud-docker-network/actions/workflows/shellcheck.yml)
[![Test Installation](https://github.com/sanghaklee-gcloud/gcloud-docker-network/actions/workflows/test-install.yml/badge.svg)](https://github.com/sanghaklee-gcloud/gcloud-docker-network/actions/workflows/test-install.yml)

GCloud 환경에서 Docker 컨테이너의 호스트 접근을 위한 iptables 관리 도구

## 설치

```bash
# 설치
curl -LsSf https://raw.githubusercontent.com/sanghaklee-gcloud/gcloud-docker-network/main/install.sh | sh

# 삭제
curl -LsSf https://raw.githubusercontent.com/sanghaklee-gcloud/gcloud-docker-network/main/install.sh | sh -s -- --uninstall
```

## 사용법

```bash
# 포트 규칙 추가
gcloud-docker-network add 8080 3000 5000

# 포트 상태 확인
gcloud-docker-network check 8080

# Docker 관련 규칙 목록
gcloud-docker-network list

# 포트 규칙 삭제
gcloud-docker-network del 8080

# 전체 INPUT 규칙 보기
gcloud-docker-network show-all

# 도움말
gcloud-docker-network help
```

## 옵션

- `--dry-run` - 실행하지 않고 명령만 확인 (add/del/check 명령)
- `-f, --force` - INPUT 정책 확인 프롬프트 생략 (add 명령만)

## 예시

```bash
# 테스트 후 추가 (권장)
gcloud-docker-network add --dry-run 8080
gcloud-docker-network add 8080

# 확인 없이 강제 추가
gcloud-docker-network add -f 8080

# 규칙 확인 및 삭제
gcloud-docker-network list
gcloud-docker-network del 8080

# 영구 저장
sudo iptables-save > /etc/iptables/rules.v4
```

## 규칙 패턴

```bash
iptables -A INPUT -i br+ -p tcp --dport PORT -m comment --comment "Docker-Host access rule DATE" -j ACCEPT
```

## 주의사항

- 포트는 필수 인자 (1-65535 범위)
- INPUT 체인 정책이 DROP이 아니면 확인 프롬프트 표시
- 옵션은 포트 번호 앞에 위치: `command [options] ports...`
- 변경사항은 `iptables-save`로 영구 저장 필요

## 요구사항

- Linux 환경
- sudo 권한
- Docker 설치
- 기본 유틸리티: iptables, grep, awk