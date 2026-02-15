#!/bin/bash
# ============================================================
# Surface Pro 8 + WD SN740 NVMe — Ubuntu Suspend Fix
# Uninstaller — removes all changes
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }

if [[ $EUID -ne 0 ]]; then
    error "루트 권한이 필요합니다.  sudo bash $0"
    exit 1
fi

echo "============================================"
echo " Surface Pro 8 + SN740 — Fix 제거"
echo "============================================"
echo ""

# 1. Remove suspend hook
if [[ -f /usr/lib/systemd/system-sleep/nvme-suspend.sh ]]; then
    rm -f /usr/lib/systemd/system-sleep/nvme-suspend.sh
    info "NVMe suspend hook 제거 완료"
else
    echo "  NVMe suspend hook 없음 (스킵)"
fi

# 2. Remove udev rule
if [[ -f /etc/udev/rules.d/60-nvme-sn740-no-d3.rules ]]; then
    rm -f /etc/udev/rules.d/60-nvme-sn740-no-d3.rules
    udevadm control --reload-rules 2>/dev/null
    info "udev 규칙 제거 완료"
else
    echo "  udev 규칙 없음 (스킵)"
fi

# 3. Restore logind.conf (remove our HandleLidSwitch lines)
sed -i '/^HandleLidSwitch=suspend$/d'              /etc/systemd/logind.conf
sed -i '/^HandleLidSwitchExternalPower=suspend$/d'  /etc/systemd/logind.conf
sed -i '/^HandleLidSwitchDocked=ignore$/d'          /etc/systemd/logind.conf
info "logind.conf 복원 완료"

echo ""
echo "============================================"
echo " 제거 완료!"
echo " GRUB 변경은 /etc/default/grub.bak.* 에서"
echo " 수동으로 복원하세요."
echo " 재부팅이 필요합니다."
echo "============================================"
