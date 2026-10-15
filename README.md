# Surface Pro 8 + WD SN740 NVMe Fix

**[English](#english)** | 한국어

Surface Pro 8에서 **WD SN740 NVMe** 사용 시 발생하는 **절전 크래시 / BSOD** 문제를 수정하는 스크립트 모음입니다.

Ubuntu와 Windows 모두 지원하며, 자동 설치 / 수동 설치 버전을 제공합니다.

> **2026-10 업데이트 — 권장 방법이 바뀌었습니다.**
> Windows에서 기존 전원 설정 방식(`windows/`)은 Modern Standby 크래시를 막지 못한다는 것을 시험으로 확인했습니다.
> 대신 **부팅 전에 SSD 슬롯의 PCIe 링크를 Gen3로 제한**하는 [`uefi-gen3-link-cap/`](uefi-gen3-link-cap/README.md)을 추가했습니다.
> 하드웨어 저전력에 들어간 절전 9회(커버 닫기 6회 포함)가 비정상 종료 없이 모두 정상 복귀했고, 절전 중 소모는 약 0.26–0.51 W였습니다.

## 문제 증상

| OS | 증상 |
|----|------|
| **Ubuntu** | 절전(suspend) 또는 덮개 닫기 후 **블랙스크린 / 커널 패닉** |
| **Windows** | 절전 후 또는 사용 중 **BSOD** (`WHEA_UNCORRECTABLE_ERROR`) |
| **Windows** | 절전 몇 분 안에 BSOD 없이 **리셋**: 프로그램이 닫히고 `Kernel-Power 41` (`ConnectedStandbyInProgress=true`, `BugcheckCode=0`), 다음 부팅에 WHEA 기록. 가끔 복귀 시 화면이 켜지지 않아 전원 버튼을 길게 눌러야 함 |

## 근본 원인

**WD SN740** (Sandisk, PCI ID `15b7:5015`)은 PCIe Gen 4 NVMe SSD입니다.

Surface Pro 8의 SSD 슬롯은 CPU 직결 PCIe 4.0 포트(루트 포트 `00:06.0`)라 SN740이 **Gen4 x4**로 연결됩니다. 이 **Gen4 링크 자체가 불안정**해서, 절전 중 링크가 저전력 상태(L1.2, D3cold)를 오가며 다시 연결될 때 확률적으로 실패하고 시스템이 크래시됩니다.

Surface Pro 8은 **Modern Standby (s2idle)** 만 지원하며, 전통적인 S3 sleep이 불가능합니다.

```
절전 진입 → NVMe 저전력(D3cold / L1.2) → PCIe 링크 저전력
→ 복귀 시 Gen 4 링크 재연결 실패 → 크래시
```

2026-10 조사에서 UEFI Shell로 읽은 AER 레지스터에 **Gen4 링크 오류**가 남아 있었습니다: SSD 쪽 Receiver Error / Bad TLP / Bad DLLP, 16 GT/s **레인 3 패리티 불일치**, 루트 포트 쪽 재전송 타이머 초과. Windows는 이 기기에서 AER 제어권이 없어 이벤트 로그에 남지 않습니다. 자세한 근거는 [uefi-gen3-link-cap/README.md](uefi-gen3-link-cap/README.md)에 있습니다.

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
├── uefi-gen3-link-cap/     ← ★ 권장 (2026-10): 부팅 전 PCIe Gen3 제한
│   ├── README.md           ← 근거, 원리, 설치/확인/제거, 한계
│   ├── Install-Gen3.ps1    ← 설치 (관리자, -DryRun 지원)
│   ├── Uninstall-Gen3.ps1  ← 제거
│   ├── Check-Gen3.ps1      ← 현재 링크 속도 확인
│   ├── startup.nsh         ← UEFI Shell 시작 스크립트
│   └── UefiBoot.ps1        ← UEFI 부팅 변수 공용 함수
│
├── windows/                ← 구버전 (Modern Standby 크래시는 막지 못함)
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

### Windows — PCIe Gen3 링크 제한 (권장)

**Secure Boot를 꺼야 합니다.** 요구 사항과 보안 영향은 [uefi-gen3-link-cap/README.md](uefi-gen3-link-cap/README.md)를 먼저 읽으세요.

```powershell
git clone https://github.com/RB3159/surface-pro-sn740-fix.git
cd surface-pro-sn740-fix\uefi-gen3-link-cap
# 관리자 PowerShell
powershell -ExecutionPolicy Bypass -File .\Install-Gen3.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File .\Install-Gen3.ps1
```

재시작 후 로그온 경고가 없으면 적용된 것입니다(`Check-Gen3.ps1`로 확인).

### Windows — 전원 설정 방식 (구버전)

> 2026-10 시험에서 PCIe ASPM 끄기, AHCI LPM 끄기 등으로는 Modern Standby 리셋이 계속 발생했습니다. 또 `NoIdleD3`/`NoLPM` 값은 현재 Windows 11의 `stornvme.sys`가 읽지 않습니다(`storahci.sys`에만 있음). 참고용으로 남겨둡니다.

1. 이 저장소를 다운로드하거나 clone
2. `windows/auto/install.cmd`를 **우클릭 → 관리자 권한으로 실행**
3. 완료! (매 부팅 + Windows Update 후 자동 재적용)

수동 설치는 [windows/manual/README.md](windows/manual/README.md) 참조

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

### Windows — PCIe Gen3 링크 제한 (권장)

| 항목 | 변경 내용 |
|------|-----------|
| ESP | `\EFI\Gen3`에 UEFI Shell + `startup.nsh` |
| UEFI 부팅 순서 | `SN740 Gen3 (UEFI Shell)` 항목을 1순위로 추가 (기존 항목 유지) |
| 매 부팅 | 루트 포트 `00:06.0` Target Link Speed = 8 GT/s, 링크 재학습 → rEFInd 또는 Windows Boot Manager |
| 스케줄 태스크 | 로그온 시 링크가 Gen3가 아니면 경고 |
| SSD 펌웨어 / 레지스트리 | 변경 없음 |

### Windows — 전원 설정 방식 (구버전)

| 항목 | 변경 내용 |
|------|-----------|
| AHCI ASPM | HIPM/DIPM 비활성화 (AC/DC = 0) |
| PCIe Link State | 링크 상태 전원 관리 비활성화 (AC/DC = 0) |
| NVMe Idle Timeout | 비활성화 (= 0) |
| NVMe NOPPME | 비활성화 (= 0) |
| 스케줄 태스크 | 부팅 시 + Windows Update 후 자동 재적용 |

## 면책 조항 (Disclaimer)

이 저장소의 스크립트와 설정은 **Claude Opus 4.6** (Anthropic)을 사용하여 작성되었습니다. 2026-10 업데이트(`uefi-gen3-link-cap/`)는 **Claude Opus 5.5**로 작성했습니다.

`uefi-gen3-link-cap/`은 Secure Boot를 끈 상태에서 부팅 전에 PCI 설정 공간에 직접 쓰고 UEFI 부팅 항목을 바꿉니다. 한 대의 기기에서만 검증했습니다.

**이 스크립트를 사용하여 발생하는 모든 문제에 대해 어떠한 책임도 지지 않습니다.**
시스템 레지스트리, GRUB 설정, 전원 관리 등 핵심 시스템 구성을 변경하므로, 사용 전 반드시 백업하고 내용을 확인한 뒤 본인 책임하에 적용하세요.

> **USE AT YOUR OWN RISK.** The author assumes no liability for any damage or data loss caused by using these scripts. Always back up your system before applying changes.

## 라이선스

MIT License

---

## English

Scripts that fix **Modern Standby crashes / BSODs** on a **Surface Pro 8 with a WD SN740 NVMe SSD**, for Windows and Ubuntu.

> **October 2026 update — the recommended Windows fix has changed.**
> Testing showed that the power-setting approach in `windows/` does not prevent Modern Standby resets.
> The new [`uefi-gen3-link-cap/`](uefi-gen3-link-cap/README.md#english) **caps the SSD slot's PCIe link at Gen3 before the OS boots**.
> With it, all 9 sleeps that reached hardware low power (6 of them by closing the cover) resumed normally with no unexpected shutdowns, drawing about 0.26–0.51 W while asleep.

### Symptoms

| OS | Symptom |
|----|---------|
| **Ubuntu** | Black screen / kernel panic after suspend or closing the cover |
| **Windows** | BSOD (`WHEA_UNCORRECTABLE_ERROR`) after sleep or during use |
| **Windows** | Silent **reset** a few minutes into sleep: programs are closed, `Kernel-Power 41` with `ConnectedStandbyInProgress=true` and `BugcheckCode=0`, a WHEA record at the next boot. Sometimes the screen stays black on wake until the power button is held down |

### Root cause

The Surface Pro 8 SSD slot is a CPU-attached PCIe 4.0 port (root port `00:06.0`, Intel `8086:9A09`), so the WD SN740 (`15b7:5015`) links at **Gen4 x4**. That **Gen4 link is marginal**: during Modern Standby it enters and leaves low-power states (L1.2, D3cold), and re-establishing it can fail, which resets the platform. The Surface Pro 8 supports only Modern Standby (s2idle), not S3.

AER registers read from a UEFI Shell showed **Gen4 link errors**: receiver errors / Bad TLP / Bad DLLP on the SSD, a 16 GT/s **parity mismatch on lane 3**, and replay timeouts on the root port. Windows does not get AER control on this platform, so none of this shows up in the event log. Details: [uefi-gen3-link-cap/README.md](uefi-gen3-link-cap/README.md#english).

### Windows — PCIe Gen3 link cap (recommended)

**Secure Boot must be off.** Read the requirements and security impact in [uefi-gen3-link-cap/README.md](uefi-gen3-link-cap/README.md#english) first.

```powershell
git clone https://github.com/RB3159/surface-pro-sn740-fix.git
cd surface-pro-sn740-fix\uefi-gen3-link-cap
# elevated PowerShell
powershell -ExecutionPolicy Bypass -File .\Install-Gen3.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File .\Install-Gen3.ps1
```

Restart once. If no warning appears after you sign in, the cap is active (check with `Check-Gen3.ps1`).

| Item | Change |
|------|--------|
| ESP | UEFI Shell + `startup.nsh` in `\EFI\Gen3` |
| UEFI boot order | Adds `SN740 Gen3 (UEFI Shell)` as the first entry; existing entries are kept |
| Every boot | Root port `00:06.0` Target Link Speed = 8 GT/s, link retrain, then rEFInd or Windows Boot Manager |
| Scheduled task | Warns at sign-in if the link is not Gen3 |
| SSD firmware / registry | Unchanged |

### Windows — power settings (legacy)

`windows/` turns off PCIe ASPM, AHCI link power management and the NVMe idle timeout, and sets `NoIdleD3` / `NoLPM`. In October 2026 testing these did **not** stop the Modern Standby resets (including with ASPM off), and `NoIdleD3` / `NoLPM` are not read by the current Windows 11 `stornvme.sys` (they only exist in `storahci.sys`). Kept for reference: right-click `windows/auto/install.cmd` → Run as administrator, or see [windows/manual/README.md](windows/manual/README.md).

### Ubuntu

```bash
git clone https://github.com/RB3159/surface-pro-sn740-fix.git
cd surface-pro-sn740-fix/ubuntu/auto
sudo bash install.sh
sudo reboot
```

| Item | Change |
|------|--------|
| GRUB | Removes `pcie_aspm=off`, adds `nvme_core.default_ps_max_latency_us=0` |
| Suspend hook | Blocks NVMe D3cold (`d3cold_allowed=0`, `power/control=on`) |
| udev | Blocks D3cold for the SN740 at boot |
| logind | Closing the cover → suspend |

Manual steps: [ubuntu/manual/README.md](ubuntu/manual/README.md). The Gen3 cap also applies to Linux when it is booted through rEFInd, but that combination has not been tested.

### Applies to

- **Hardware**: Surface Pro 8 (Intel 11th Gen Tiger Lake)
- **NVMe**: WD SN740 (`15b7:5015`), PCIe Gen 4
- **OS**: Ubuntu 22.04+ (linux-surface kernel), Windows 10/11
- The Ubuntu and legacy Windows scripts may also work on other devices with an SN740. `uefi-gen3-link-cap/` refuses to install on anything other than the Surface Pro 8 PCIe topology.

### Disclaimer

The scripts in this repository were written with **Claude Opus 4.6** (Anthropic). The October 2026 update (`uefi-gen3-link-cap/`) was written with **Claude Opus 5.5**.

`uefi-gen3-link-cap/` writes to PCI configuration space before boot and changes UEFI boot entries, with Secure Boot off. It has been verified on one device only.

**USE AT YOUR OWN RISK.** The author assumes no liability for any damage or data loss caused by using these scripts. Always back up your system before applying changes.

### License

MIT License
