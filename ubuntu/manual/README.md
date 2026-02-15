# Ubuntu 수동 설치 가이드

Surface Pro 8 + WD SN740 NVMe 절전 크래시 수동 수정 방법입니다.

## 문제 원인

- **SN740 NVMe**가 s2idle 절전 시 **D3cold** 상태로 진입
- 복귀 시 **PCIe Gen 4 링크 트레이닝 실패** → 커널 패닉 / 블랙스크린
- `pcie_aspm=off` 설정이 있으면 **S0ix 진입 자체가 차단**되어 절전이 제대로 안 됨

## 단계별 수동 적용

### 1. GRUB 커널 파라미터 수정

```bash
sudo nano /etc/default/grub
```

`GRUB_CMDLINE_LINUX_DEFAULT` 줄을 아래와 같이 수정:

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash nvme_core.default_ps_max_latency_us=0 snd_hda_intel.dmic_detect=0"
```

> ⚠ `pcie_aspm=off`가 있으면 **반드시 제거**하세요. S0ix 진입을 차단합니다.

적용:
```bash
sudo update-grub
```

### 2. NVMe suspend/resume 훅 설치

`files/nvme-suspend.sh`를 복사:

```bash
sudo cp files/nvme-suspend.sh /usr/lib/systemd/system-sleep/nvme-suspend.sh
sudo chmod +x /usr/lib/systemd/system-sleep/nvme-suspend.sh
```

> NVMe PCI 주소가 다를 경우 파일 내 `NVME_PCI=` 값을 수정하세요.
> 확인 방법: `lspci -nn | grep -i 'non-volatile'`

### 3. udev 규칙 설치

`files/60-nvme-sn740-no-d3.rules`를 복사:

```bash
sudo cp files/60-nvme-sn740-no-d3.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

### 4. logind.conf 수정

```bash
sudo nano /etc/systemd/logind.conf
```

`[Login]` 섹션에 추가:

```ini
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=ignore
```

### 5. 재부팅

```bash
sudo reboot
```

## 적용 확인

```bash
# GRUB 파라미터 확인
cat /proc/cmdline

# NVMe D3cold 상태 확인 (0이면 정상)
cat /sys/bus/pci/devices/0000:01:00.0/d3cold_allowed

# S0ix residency 확인 (0보다 크면 정상)
sudo cat /sys/kernel/debug/pmc_core/slp_s0_residency_usec
```

## 제거 방법

```bash
sudo rm /usr/lib/systemd/system-sleep/nvme-suspend.sh
sudo rm /etc/udev/rules.d/60-nvme-sn740-no-d3.rules
# logind.conf에서 HandleLidSwitch 관련 줄 제거
# GRUB에서 커널 파라미터 원복 후 sudo update-grub
sudo reboot
```
