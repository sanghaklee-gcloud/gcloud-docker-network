#!/usr/bin/env bash
# gcloud-docker-network - Docker iptables management tool

VERSION="1.0.2"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 옵션 및 포트 파싱
parse_options_and_ports() {
    DRY_RUN=false
    FORCE=false
    PORTS=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            *)
                PORTS+=("$1")
                shift
                ;;
        esac
    done
}

# 포트 검증 (숫자만 허용)
validate_ports() {
    if [ ${#PORTS[@]} -eq 0 ]; then
        echo -e "${RED}❌ Error: 포트 번호를 입력해주세요${NC}"
        echo -e "${YELLOW}Usage: gcloud-docker-network $1 [options] <ports...>${NC}"
        exit 1
    fi

    for port in "${PORTS[@]}"; do
        if ! [[ "$port" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}❌ Error: 잘못된 포트 번호 $port - 숫자만 가능${NC}"
            exit 1
        fi
        if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
            echo -e "${RED}❌ Error: 포트 번호 범위 초과 $port - 1~65535${NC}"
            exit 1
        fi
    done
}

# INPUT chain policy 확인
check_input_policy() {
    local POLICY
    POLICY=$(sudo iptables -nvL INPUT | head -1 | grep -oP 'policy \K\w+')
    if [ "$POLICY" != "DROP" ]; then
        return 1  # DROP이 아님
    fi
    return 0  # DROP임
}

# 포트 규칙 존재 여부 확인 (커멘트 제외)
check_port_exists() {
    local PORT=$1
    # br+ 인터페이스와 포트만 확인 (커멘트는 무시)
    if sudo iptables -nvL INPUT | grep -E "br\+" | grep -q "dpt:$PORT"; then
        return 0  # 존재함
    else
        return 1  # 존재하지 않음
    fi
}

# iptables 출력 (헤더 포함)
show_iptables_with_header() {
    local CHAIN="INPUT"
    local FILTER="$1"
    local FULL_OUTPUT

    # 전체 출력 저장
    FULL_OUTPUT=$(sudo iptables -nvL $CHAIN --line-numbers)

    # 헤더 출력 (첫 2줄)
    echo "$FULL_OUTPUT" | head -2

    # 필터링된 내용 출력
    if [ -n "$FILTER" ]; then
        echo "$FULL_OUTPUT" | tail -n +3 | grep -E "$FILTER" || echo "  Docker 관련 규칙 없음"
    else
        echo "$FULL_OUTPUT" | tail -n +3
    fi
}

case "$1" in
    version|--version|-v)
        echo "$VERSION"
        ;;
        
    list)
        echo -e "${CYAN}Docker 관련 iptables 규칙:${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY-RUN] sudo iptables -nvL INPUT --line-numbers"
        else
            show_iptables_with_header "br-|br\+|docker|Docker"
        fi
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # 전체 규칙 수 표시
        TOTAL=$(sudo iptables -nvL INPUT | tail -n +3 | wc -l)
        DOCKER_RULES=$(sudo iptables -nvL INPUT | tail -n +3 | grep -E "br-|br\+|docker|Docker" | wc -l)
        echo -e "${BLUE}Total: $DOCKER_RULES Docker rules / $TOTAL total rules${NC}"
        ;;
        
    add)
        shift
        parse_options_and_ports "$@"
        validate_ports "add"

        # INPUT policy 체크 (dry-run이 아니고, force가 아닐 때만)
        if ! check_input_policy; then
            if [ "$FORCE" = false ] && [ "$DRY_RUN" = false ]; then
                echo -e "${YELLOW}⚠️  경고: INPUT Chain Policy가 DROP이 아닙니다${NC}"
                POLICY=$(sudo iptables -nvL INPUT | head -1 | grep -oP 'policy \K\w+')
                echo -e "  현재 Policy: ${CYAN}$POLICY${NC}"
                echo ""
                echo -e "${YELLOW}INPUT Policy가 DROP이 아닌 경우 이 규칙이 필요하지 않을 수 있습니다.${NC}"
                echo -e "계속 진행하시겠습니까? [y/N] "
                read -r response
                if [[ ! "$response" =~ ^[yY]$ ]]; then
                    echo -e "${RED}취소되었습니다.${NC}"
                    echo -e "${BLUE}💡 강제로 진행하려면 -f 옵션을 사용하세요: gcloud-docker-network add -f ${PORTS[*]}${NC}"
                    exit 0
                fi
            fi
        fi

        DATE=$(date +%Y-%m-%d)

        if [ "$DRY_RUN" = true ]; then
            echo -e "${YELLOW}🔍 DRY-RUN MODE: 실제로 실행되지 않습니다${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        else
            echo -e "${CYAN}규칙 추가 중...${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi

        for PORT in "${PORTS[@]}"; do
            # 이미 존재하는지 확인 (커멘트 제외)
            if check_port_exists "$PORT"; then
                echo -e "${YELLOW}⚠️  Port $PORT already exists - skipping${NC}"
                EXISTING_RULE=$(sudo iptables -nvL INPUT --line-numbers | grep "br\+" | grep "dpt:$PORT" | head -1)
                echo "   └→ Existing: $EXISTING_RULE"
                continue
            fi

            CMD="sudo iptables -A INPUT -i br+ -p tcp --dport $PORT -m comment --comment \"Docker-Host access rule $DATE\" -j ACCEPT"

            if [ "$DRY_RUN" = true ]; then
                echo "[DRY-RUN] $CMD"
            else
                eval "$CMD"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✅ Added port $PORT${NC}"
                    # 방금 추가한 규칙 찾기
                    NEW_RULE=$(sudo iptables -nvL INPUT --line-numbers | grep "br\+" | grep "dpt:$PORT" | tail -1)
                    echo "   └→ New rule: $NEW_RULE"
                else
                    echo -e "${RED}❌ Failed to add port $PORT${NC}"
                fi
            fi
        done

        if [ "$DRY_RUN" = false ]; then
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo -e "${BLUE}💡 영구 저장: sudo iptables-save > /etc/iptables/rules.v4${NC}"
        fi
        ;;
        
    del)
        shift
        parse_options_and_ports "$@"
        validate_ports "del"

        if [ "$DRY_RUN" = true ]; then
            echo -e "${YELLOW}🔍 DRY-RUN MODE: 실제로 실행되지 않습니다${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        else
            echo -e "${CYAN}규칙 삭제 중...${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi

        for PORT in "${PORTS[@]}"; do
            # br+ 인터페이스와 포트로 규칙 찾기
            RULE_INFO=$(sudo iptables -nvL INPUT --line-numbers | grep "br\+" | grep "dpt:$PORT" | head -1)

            if [ -n "$RULE_INFO" ]; then
                RULE_NUM=$(echo "$RULE_INFO" | awk '{print $1}')

                # 삭제하기 전에 규칙 정보 저장
                SAVED_RULE_INFO="$RULE_INFO"

                CMD="sudo iptables -D INPUT $RULE_NUM"

                if [ "$DRY_RUN" = true ]; then
                    echo "Port $PORT - Rule #$RULE_NUM:"
                    echo "  $SAVED_RULE_INFO"
                    echo "[DRY-RUN] $CMD"
                    echo ""
                else
                    eval "$CMD"
                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}✅ Removed port $PORT${NC}"
                        echo "   └→ Deleted: $SAVED_RULE_INFO"
                    else
                        echo -e "${RED}❌ Failed to remove port $PORT${NC}"
                    fi
                fi
            else
                echo -e "${RED}❌ Port $PORT rule not found${NC}"
            fi
        done

        if [ "$DRY_RUN" = false ]; then
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi
        ;;
        
    check)
        shift
        parse_options_and_ports "$@"
        validate_ports "check"

        echo -e "${CYAN}포트별 상태 확인:${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # INPUT 정책 확인
        POLICY=$(sudo iptables -nvL INPUT | head -1 | grep -oP 'policy \K\w+')
        if [ "$POLICY" = "DROP" ]; then
            echo -e "  ${YELLOW}⚠️  INPUT Chain Policy: DROP - 제한적${NC}"
        else
            echo -e "  ${GREEN}✓ INPUT Chain Policy: ACCEPT - 허용${NC}"
        fi
        echo ""

        for PORT in "${PORTS[@]}"; do
            echo -n "  Port $PORT: "
            RULE=$(sudo iptables -nvL INPUT --line-numbers | grep "br\+" | grep "dpt:$PORT" | head -1)
            if [ -n "$RULE" ]; then
                echo -e "${GREEN}✅ 허용됨${NC}"
                if [ "$DRY_RUN" = true ] || [ -n "$VERBOSE" ]; then
                    echo "    └→ $RULE"
                fi
            else
                echo -e "${RED}❌ 차단됨${NC}"
                if [ "$DRY_RUN" = true ]; then
                    echo "    └→ 추가 필요: gcloud-docker-network add $PORT"
                fi
            fi
        done
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        ;;
        
    show-all|all)
        echo -e "${CYAN}전체 INPUT Chain 규칙:${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        sudo iptables -nvL INPUT --line-numbers
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # 통계 표시
        TOTAL=$(sudo iptables -nvL INPUT | tail -n +3 | wc -l)
        DOCKER_RULES=$(sudo iptables -nvL INPUT | tail -n +3 | grep -E "br-|br\+|docker|Docker" | wc -l)
        ACCEPT_RULES=$(sudo iptables -nvL INPUT | tail -n +3 | grep -c "ACCEPT")
        DROP_RULES=$(sudo iptables -nvL INPUT | tail -n +3 | grep -c "DROP")

        echo -e "${BLUE}Statistics:${NC}"
        echo "  Total rules: $TOTAL"
        echo "  Docker rules: $DOCKER_RULES"
        echo "  ACCEPT rules: $ACCEPT_RULES"
        echo "  DROP rules: $DROP_RULES"
        ;;
        
    help|--help|-h|*)
        echo -e "${CYAN}gcloud-docker-network v${VERSION}${NC}"
        echo "Docker iptables 관리 도구 for GCloud"
        echo ""
        echo -e "${YELLOW}Usage:${NC}"
        echo "  gcloud-docker-network <command> [options] <ports...>"
        echo ""
        echo -e "${YELLOW}Commands:${NC}"
        echo "  list              Docker 관련 규칙 목록 - 헤더 포함"
        echo "  show-all          전체 INPUT 규칙 보기"
        echo "  check <ports...>  포트 상태 확인 - 포트 필수"
        echo "  add <ports...>    포트 규칙 추가 - 포트 필수, 중복 체크"
        echo "  del <ports...>    포트 규칙 삭제 - 포트 필수"
        echo "  version           버전 정보"
        echo "  help              이 도움말"
        echo ""
        echo -e "${YELLOW}Options:${NC}"
        echo "  --dry-run         실제 실행하지 않고 명령어만 출력"
        echo "  -f, --force       확인 메시지 무시 - add 명령어에서만 사용"
        echo ""
        echo -e "${YELLOW}Notes:${NC}"
        echo "  - 포트 번호는 1-65535 범위의 숫자만 가능합니다"
        echo "  - add 명령어는 INPUT policy가 DROP이 아닐 때 확인 메시지를 표시합니다"
        echo "  - -f 옵션으로 확인 메시지를 건너뛸 수 있습니다"
        echo ""
        echo -e "${YELLOW}Examples:${NC}"
        echo "  gcloud-docker-network check 8080 3000"
        echo "  gcloud-docker-network add 8080 3000 5000"
        echo "  gcloud-docker-network add --dry-run 8080"
        echo "  gcloud-docker-network add -f 8080           # 확인 없이 추가"
        echo "  gcloud-docker-network del --dry-run 8080"
        echo "  gcloud-docker-network list"
        echo "  gcloud-docker-network show-all"
        ;;
esac