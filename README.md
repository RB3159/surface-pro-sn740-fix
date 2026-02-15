# Surface Pro 8 + WD SN740 NVMe Fix

Surface Pro 8에서 **WD SN740 NVMe** 사용 시 발생하는 **절전 크래시 / BSOD** 문제를 수정하는 스크립트 모음입니다.

Ubuntu와 Windows 모두 지원하며, 자동 설치 / 수동 설치 버전을 제공합니다.

## 문제 증상

| OS | 증상 |
|----|------|
| **Ubuntu** | 절전(suspend) 또는 덮개 닫기 후 **블랙스크린 / 커널 패닉** |
| **Windows** | 절전 후 또는 사용 중 **BSOD** (`WHEA_UNCORRECTABLE_ERROR`) |

## 근본 원인

**WD SN740** (Sandisk, PCI ID `15b7:5015`)은 PCIe Gen 4 NVMe SSD입니다.

절전 시 OS가 NVMe를 **D3cold** 전력 상태로 전환하면, 복귀 시 **PCIe Gen 4 링크 트레이닝이 실패**하여 시스템이 크래시됩니다.

Surface Pro 8은 **Modern Standby (s2idle)** 만 지원하며, 전통적인 S3 sleep이 불가능합니다.

```
절전 진입 → NVMe D3cold 전환 → PCIe 링크 다운
→ 복귀 시도 → Gen 4 링크 트레이닝 실패 → 크래시
```

## 저장소 구조

```
surface-pro-sn740-fix/
├── README.md               ← 이 파일
│
├── ubuntu/
│   ├── auto/
│   │   ├── install.sh      ← 원클릭 자동 설치 (sudo bash install.sh)
│   │   └── uninstall.sh    ← 제거 스크립트
│   └── manual/
│       ├── README.md       ← 단계별 수동 가이드
│       └── files/
│           ├── nvme-suspend.sh           ← suspend hook
│           └── 60-nvme-sn740-no-d3.rules ← udev 규칙
│
├── windows/
│   ├── auto/
│   │   ├── install.cmd     ← 원클릭 자동 설치 (관리자 실행)
│   │   └── uninstall.cmd   ← 제거 스크립트
│   ├── manual/
│   │   ├── README.md       ← 단계별 수동 가이드
│   │   └── files/
│   │       ├── disable-pcie-pm.reg  ← PCIe 전원관리 비활성화
│   │       └── nvme-no-d3.reg       ← NVMe D3 비활성화
│   └── scripts/
│       ├── fix-pcie-power.ps1    ← PowerShell 전원 설정 스크립트
│       └── SN740-PCIe-Fix.xml   ← 스케줄 태스크 XML
```

## 빠른 시작

### Ubuntu — 자동 설치

```bash
git clone https://github.com/RB3159/surface-pro-sn740-fix.git
cd surface-pro-sn740-fix/ubuntu/auto
sudo bash install.sh
sudo reboot
```

### Ubuntu — 수동 설치

[ubuntu/manual/README.md](ubuntu/manual/README.md) 참조

### Windows — 자동 설치

1. 이 저장소를 다운로드하거나 clone
2. `windows/auto/install.cmd`를 **우클릭 → 관리자 권한으로 실행**
3. 완료! (매 부팅 + Windows Update 후 자동 재적용)

### Windows — 수동 설치

[windows/manual/README.md](windows/manual/README.md) 참조

## 적용 대상

- **하드웨어**: Surface Pro 8 (Intel 11th Gen Tiger Lake)
- **NVMe**: WD SN740 (`15b7:5015`) — PCIe Gen 4
- **OS**: Ubuntu 22.04+ (linux-surface 커널), Windows 10/11
- 동일 SN740을 사용하는 **다른 기기에서도 동작할 수 있음**

## 변경 사항 요약

### Ubuntu

| 항목 | 변경 내용 |
|------|-----------|
| GRUB | `pcie_aspm=off` 제거, `nvme_core.default_ps_max_latency_us=0` 추가 |
| Suspend hook | NVMe D3cold 차단 (`d3cold_allowed=0`, `power/control=on`) |
| udev | 부팅 시 SN740 자동 D3cold 차단 |
| logind | 덮개 닫기 → suspend 설정 |

### Windows

| 항목 | 변경 내용 |
|------|-----------|
| AHCI ASPM | HIPM/DIPM 비활성화 (AC/DC = 0) |
| PCIe Link State | 링크 상태 전원 관리 비활성화 (AC/DC = 0) |
| NVMe Idle Timeout | 비활성화 (= 0) |
| NVMe NOPPME | 비활성화 (= 0) |
| 스케줄 태스크 | 부팅 시 + Windows Update 후 자동 재적용 |

## 면책 조항 (Disclaimer)

이 저장소의 스크립트와 설정은 **Claude Opus 4.6** (Anthropic)을 사용하여 작성되었습니다.

**이 스크립트를 사용하여 발생하는 모든 문제에 대해 어떠한 책임도 지지 않습니다.**
시스템 레지스트리, GRUB 설정, 전원 관리 등 핵심 시스템 구성을 변경하므로, 사용 전 반드시 백업하고 내용을 확인한 뒤 본인 책임하에 적용하세요.

> **USE AT YOUR OWN RISK.** The author assumes no liability for any damage or data loss caused by using these scripts. Always back up your system before applying changes.

## 라이선스

MIT License
