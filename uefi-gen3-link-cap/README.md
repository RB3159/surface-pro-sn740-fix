# PCIe Gen3 링크 제한 (권장, 2026-10)

**[English](#english)** | 한국어

Surface Pro 8의 SSD 슬롯은 CPU 직결 PCIe 4.0 포트(루트 포트 `00:06.0`, Intel `8086:9A09`)입니다. WD SN740은 여기서 **Gen4(16 GT/s) x4**로 연결되는데, 이 링크가 불안정해 Modern Standby 중 링크가 저전력 상태를 오갈 때 시스템이 리셋됩니다.

이 방법은 **매 부팅마다 OS가 시작되기 전에 루트 포트의 최대 링크 속도를 Gen3(8 GT/s)로 낮춥니다.** SSD 펌웨어, Windows 레지스트리, NVMe 전원 관리는 바꾸지 않습니다.

## 근거

### 1. Gen4 링크에서 실제 오류가 기록됨

UEFI Shell로 읽은 PCIe AER 레지스터입니다. Surface Pro 8에서는 OS가 AER 제어권을 받지 못해(`PCIExpressAERControl=False`) **Windows 이벤트 로그에 이 오류가 남지 않습니다.**

| 위치 | 기록 | 의미 |
|---|---|---|
| SSD AER Correctable Status | `0x000000C1` | Receiver Error, Bad TLP, Bad DLLP (루트 포트 → SSD 방향 신호 손상) |
| SSD Physical Layer 16.0 GT/s | Local Data Parity Mismatch `0x08` | **레인 3**에서 16 GT/s 데이터 패리티 불일치 |
| 루트 포트 AER Correctable Status | `0x00001100` | Replay Timer Timeout, REPLAY_NUM Rollover (재전송 반복) |

16 GT/s 등화(equalization)는 양쪽 모두 Phase 1–3 성공으로 끝났지만 운용 중 오류가 발생했습니다. 한 부팅에서는 16 → 8 GT/s 속도 전환 협상 자체가 실패해 링크가 16 GT/s에 남기도 했습니다.

**한계:** AER 상태 비트는 재시작 후에도 남기 때문에, 셸에서 읽은 값에는 직전 세션뿐 아니라 **리셋 과정과 그 부팅의 펌웨어 단계(항상 Gen4)**에서 난 오류도 섞입니다. 실제로 Gen3 세션 뒤의 부팅에서도 같은 값이 다시 기록된 적이 있어, 이 값만으로 오류 발생 시점을 가릴 수는 없습니다. 16 GT/s 패리티 불일치는 16 GT/s에서만 기록되므로 Gen4 근거로 유효합니다. 결정적인 근거는 아래 절전 결과입니다.

### 2. 소프트웨어 전원 설정으로는 해결되지 않음

Gen4 상태에서 11가지 조건을 시험했습니다: PCIe ASPM 끄기/보통/최대, 어댑터 `DisableD3Cold`, `StorageD3InModernStandby=0`, NVMe 복귀 지연 제한, 동작 전력 단계 PS2 제한, 커버 분리 등. **실제 저전력(DRIPS)에 들어간 절전 약 17회 중 약 절반이** `Kernel-Power 41`(`ConnectedStandbyInProgress=true`, `BugcheckCode=0`)로 리셋됐고, 어느 설정도 실패율을 낮추지 못했습니다. 같은 부팅에서 첫 절전이 성공한 뒤의 두 번째 절전은 4번 모두 실패했습니다.

리셋이 없던 유일한 조건은 어댑터 `DisableRuntimePowerManagement=1`이었습니다. 하지만 링크가 L0에 머물러 하드웨어 저전력 0%, 절전 중 약 4 W를 소모해 실사용이 불가능했습니다.

### 3. Gen3에서의 결과

Gen3로 부팅한 4번의 부팅 동안 **저전력(DRIPS)에 들어간 절전 9회가 모두 정상 복귀**했고, 비정상 종료는 0회였습니다. 매 복귀 후 링크는 Gen3로 유지됐습니다.

| # | 절전 진입 | 전원 | 절전 시간 | HW DRIPS | 평균 소모 |
|---|---|---|---|---|---|
| 1 | 시작 메뉴 | 충전 중 | 4.8분 | 78.8% | – |
| 2 | 시작 메뉴 (**같은 부팅 두 번째 절전**) | 배터리 | 6.0분 | 94.9% | 0.40 W |
| 3 | **커버 닫기** | 배터리 | 17.1분 | 96.9% | 0.35 W |
| 4 | 화면 꺼짐 시간 초과 | 배터리 | 23.5분 | 98.4% | 0.26 W |
| 5–9 | **커버 닫기, 한 부팅에서 5회 연속** | 배터리 | 8.2–11.5분 | 91.8–98.1% | 0.31–0.51 W |

이 밖에 1분 이내로 커버를 닫았다 연 2회(저전력 진입 전)도 정상이었습니다. Gen4 실패율(약 50%/회)이라면 9회 연속 통과할 확률은 약 0.2%입니다. 밤새 절전 같은 더 긴 시험은 계속 진행 중입니다.

## 동작 원리

PCIe 링크 속도는 양쪽이 지원하는 속도 중 **루트 포트의 Target Link Speed 이하**로 협상됩니다. SSD 쪽에서 링크를 PCIe 3.0으로 제한하는 것과 같은 효과를, SSD 펌웨어를 고치지 않고 PC 쪽에서 냅니다. (Sabrent도 Surface Pro 8의 PCIe 4.0 신호 품질 문제와 3.0 제한을 [언급](https://www.reddit.com/r/Surface/comments/12sv4km/surface_pro_8_ssd_upgrade/)한 바 있습니다.)

```
전원 켜짐 → 펌웨어가 SSD를 Gen4로 연결
→ [UEFI Shell, startup.nsh]
     루트 포트 Link Control 2 (0x70) Target Link Speed = 3 (8 GT/s)
     Link Control (0x50) Retrain Link × 6   ← 16 GT/s 위에서의 속도 전환 협상이 실패할 수 있어 반복
→ rEFInd (설치돼 있으면) 또는 Windows Boot Manager
→ Windows: 링크 8 GT/s x4
```

- 재학습(retrain)은 SSD를 리셋하지 않고 링크 조건만 다시 협상합니다. 펌웨어가 SSD를 쓰고 있는 동안에도 안전합니다.
- 루트 포트 설정은 **절전(D3cold 포함) 복귀 후에도 유지**됩니다. 재부팅하면 초기화되므로 셸이 매 부팅 다시 적용합니다.
- 셸이 어떤 이유로든 실패하면 `exit`로 펌웨어에 돌아가고, 기존 부팅 순서대로 평소처럼(Gen4) 부팅됩니다.
- 부팅 항목은 셸에 `-delay 0` 옵션을 넘깁니다. 셸의 5초 "Press ESC" 대기를 건너뛰고 바로 startup.nsh를 실행하므로 셸 단계는 1–2초면 끝납니다.
- 셸은 부팅마다 날짜·시각, AER 상태 4개 값, 최종 링크 상태(`0x43` = 8 GT/s x4, `0x44` = 16 GT/s x4)를 ESP의 `\EFI\Gen3\apply\history.txt`에 덧붙입니다(부팅당 약 100바이트).

## 요구 사항

- **Surface Pro 8 + WD SN740** (`15B7:5015`), SSD가 루트 포트 `00:06.0`의 버스 1에 있을 것. 설치 스크립트가 확인하고, 다르면 중단합니다.
- **Secure Boot 꺼짐.** UEFI Shell은 Microsoft 서명이 없어 Secure Boot가 켜져 있으면 실행되지 않습니다. Surface UEFI(볼륨 업 + 전원) → Security → Secure Boot에서 끌 수 있습니다. 부팅 화면에 빨간 막대가 표시되고, 부팅 단계 악성코드 방어가 약해집니다. **이 보안상 손실을 감수할 수 있을 때만 사용하세요.**
- **BitLocker / 장치 암호화 꺼짐 또는 일시 중단.** 부팅 경로가 바뀌면 복구 키를 요구합니다. 켜진 상태에서의 동작은 검증하지 않았습니다.
- 설치 시 인터넷 연결(UEFI Shell 다운로드). 오프라인이면 같은 파일을 받아 `-ShellPath`로 지정하세요.
- 기존 Windows 우회 설정(`windows/auto`)이 설치돼 있으면 먼저 `windows/auto/uninstall.cmd`로 제거하는 것을 권장합니다.

## 설치

관리자 PowerShell에서:

```powershell
cd surface-pro-sn740-fix\uefi-gen3-link-cap
powershell -ExecutionPolicy Bypass -File .\Install-Gen3.ps1 -DryRun   # 점검과 계획만 출력, 쓰기 없음
powershell -ExecutionPolicy Bypass -File .\Install-Gen3.ps1
```

설치 스크립트가 하는 일:

1. [pbatard/UEFI-Shell](https://github.com/pbatard/UEFI-Shell) 26H1(edk2-stable202602)의 `shellx64.efi`를 받아 SHA256 `4ea080dd…7b11e0`를 확인
2. ESP에 `\EFI\Gen3\shellx64.efi`, `startup.nsh`, `gen3.marker` 복사
3. UEFI 부팅 항목 `SN740 Gen3 (UEFI Shell)` 생성(기존 Windows 항목의 장치 경로 사용, 셸 옵션 `-delay 0`) 후 BootOrder 1순위로 설정. 기존 항목과 순서는 유지
4. 로그온 시 링크가 Gen3가 아니면 경고 창을 띄우는 작업 `SN740 Gen3 Link Check` 등록
5. 설치 전 NVRAM 부팅 항목을 `%ProgramData%\SN740-Gen3\nvram-backup.json`에 백업

재시작하면 검은 셸 화면이 1–2초 보인 뒤 평소 부팅 화면으로 넘어갑니다. 혹시 `Shell>` 프롬프트에서 멈추면 `exit`를 입력하면 됩니다.

배터리에서 커버를 닫으면 절전하도록 하려면(최대 절전 우회 설정을 써 왔다면):

```powershell
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 1
powercfg /setactive SCHEME_CURRENT
```

## 확인

```powershell
powershell -ExecutionPolicy Bypass -File .\Check-Gen3.ps1
# SN740 link: Gen3 (8 GT/s) - Gen3 cap active
```

장치 관리자 → 저장소 컨트롤러 → 표준 NVM Express 컨트롤러 → 자세히 → "PCI 현재 링크 속도"가 `3`이면 적용된 것입니다.

## 제거

```powershell
powershell -ExecutionPolicy Bypass -File .\Uninstall-Gen3.ps1
```

부팅 항목, BootOrder 참조, ESP의 `\EFI\Gen3`, 로그온 작업을 제거합니다. 다음 부팅부터 Gen4로 돌아갑니다.

## 부작용과 한계

- 부팅 시간 약 1–2초 증가(셸 시작 + 재학습).
- rEFInd를 쓴다면 `\EFI\refind\refind.conf`의 `timeout`(기본 20초)을 줄이면 부팅이 훨씬 빨라집니다. 시험 기기는 3초로 설정했습니다.
- 순차 읽기 상한이 약 5 GB/s에서 **약 3.5 GB/s**로 낮아집니다(DiskSpd 128K QD32×4: 3,338 MiB/s). 일상 사용에서는 체감이 어렵습니다.
- **Secure Boot를 다시 켜거나**, 펌웨어·Windows 업데이트가 BootOrder를 바꾸면 Gen3가 적용되지 않습니다. 이때는 로그온 경고가 뜹니다. 경고가 뜬 부팅에서는 배터리로 커버를 닫지 말고 한 번 재시작하세요.
- 셸이 rEFInd를 실행하므로 rEFInd로 부팅하는 Linux에도 Gen3가 적용됩니다. Linux에서의 절전 효과는 검증하지 않았습니다.
- 한 대의 기기에서만 검증했습니다: Surface Pro 8, WD PC SN740 `SDDPTQE-2T00` 펌웨어 `73117000`, Windows 11 25H2 (26200.8457), Surface UEFI 33.106.143.

## 파일

| 파일 | 역할 |
|---|---|
| `startup.nsh` | UEFI Shell 시작 스크립트. 루트 포트 Gen3 제한·재학습·부팅 기록(`history.txt`) 후 다음 부트로더 실행 |
| `Install-Gen3.ps1` | 설치. `-DryRun`은 점검만 |
| `Uninstall-Gen3.ps1` | 제거 |
| `Check-Gen3.ps1` | 현재 링크 속도 확인. `-Popup`은 로그온 작업용 |
| `UefiBoot.ps1` | UEFI 부팅 변수·ESP 공용 함수 |

---

## English

### PCIe Gen3 link cap (recommended, October 2026)

The Surface Pro 8 SSD slot is a CPU-attached PCIe 4.0 port (root port `00:06.0`, Intel `8086:9A09`). The WD SN740 links there at **Gen4 (16 GT/s) x4**, and that link is unstable: the system resets when the link moves in and out of low-power states during Modern Standby.

This fix **lowers the root port's maximum link speed to Gen3 (8 GT/s) on every boot, before the OS starts.** It does not change the SSD firmware, the Windows registry or NVMe power management.

### Evidence

#### 1. The Gen4 link logs real errors

PCIe AER registers read from the UEFI Shell. On the Surface Pro 8 the OS does not get AER control (`PCIExpressAERControl=False`), so **these errors never reach the Windows event log.**

| Location | Value | Meaning |
|---|---|---|
| SSD AER Correctable Status | `0x000000C1` | Receiver Error, Bad TLP, Bad DLLP (signal corrupted on the root port → SSD direction) |
| SSD Physical Layer 16.0 GT/s | Local Data Parity Mismatch `0x08` | 16 GT/s data parity mismatch on **lane 3** |
| Root port AER Correctable Status | `0x00001100` | Replay Timer Timeout, REPLAY_NUM Rollover (repeated retransmission) |

16 GT/s equalization completed (phases 1–3 successful on both sides), yet errors occurred during operation. On one boot even the 16 → 8 GT/s speed-change negotiation failed and the link stayed at 16 GT/s.

**Limitation:** AER status bits survive a restart, so a value read from the shell mixes the previous session with errors from **the reset and from that boot's firmware phase (always at Gen4)**. The same values were in fact logged again on a boot that followed a Gen3 session, so these values alone cannot tell when the errors happened. The 16 GT/s parity mismatch is only logged at 16 GT/s, so it remains valid Gen4 evidence. The decisive evidence is the sleep results below.

#### 2. Software power settings do not fix it

Eleven conditions were tested at Gen4: PCIe ASPM off / moderate / maximum, adapter `DisableD3Cold`, `StorageD3InModernStandby=0`, an NVMe resume-latency limit, capping the operational power state at PS2, detaching the cover, and more. **About half of roughly 17 sleeps that reached hardware low power (DRIPS)** ended in a reset (`Kernel-Power 41`, `ConnectedStandbyInProgress=true`, `BugcheckCode=0`), and no setting lowered that rate. Every second sleep in the same boot after a successful first one failed (4 of 4).

The only condition without resets was adapter `DisableRuntimePowerManagement=1`. But the link then stays in L0, hardware low power is 0% and sleep draws about 4 W, so it is not usable.

#### 3. Results at Gen3

Across four boots at Gen3, **all 9 sleeps that reached hardware low power (DRIPS) resumed normally**, with zero unexpected shutdowns. The link stayed at Gen3 after every resume.

| # | Sleep entered by | Power | Sleep time | HW DRIPS | Average draw |
|---|---|---|---|---|---|
| 1 | Start menu | Charging | 4.8 min | 78.8% | – |
| 2 | Start menu (**second sleep in the same boot**) | Battery | 6.0 min | 94.9% | 0.40 W |
| 3 | **Closing the cover** | Battery | 17.1 min | 96.9% | 0.35 W |
| 4 | Screen-off timeout | Battery | 23.5 min | 98.4% | 0.26 W |
| 5–9 | **Closing the cover, 5 times in a row in one boot** | Battery | 8.2–11.5 min | 91.8–98.1% | 0.31–0.51 W |

Two more cover closes of under a minute (before reaching low power) were also fine. At the Gen4 failure rate (about 50% per sleep), 9 passes in a row would happen by chance about 0.2% of the time. Longer tests such as overnight sleep are ongoing.

### How it works

PCIe negotiates a link speed both sides support, **no higher than the root port's Target Link Speed**. This has the same effect as limiting the SSD to PCIe 3.0, but from the PC side and without touching the SSD firmware. (Sabrent has also [mentioned](https://www.reddit.com/r/Surface/comments/12sv4km/surface_pro_8_ssd_upgrade/) the Surface Pro 8's PCIe 4.0 signal quality and limiting to 3.0.)

```
Power on → firmware links the SSD at Gen4
→ [UEFI Shell, startup.nsh]
     Root port Link Control 2 (0x70) Target Link Speed = 3 (8 GT/s)
     Link Control (0x50) Retrain Link × 6   ← repeated: the speed change negotiated over 16 GT/s can fail
→ rEFInd (if installed) or Windows Boot Manager
→ Windows: link at 8 GT/s x4
```

- A retrain renegotiates the link without resetting the SSD, so it is safe while the firmware is using the drive.
- The root port setting **survives sleep (including D3cold)**. It is reset on reboot, so the shell reapplies it on every boot.
- If the shell fails for any reason, it `exit`s back to the firmware, which boots the next entry in the existing boot order as before (at Gen4).
- The boot entry passes `-delay 0` to the shell. It skips the shell's 5-second "Press ESC" prompt and runs startup.nsh right away, so the shell stage takes 1–2 seconds.
- On every boot the shell appends the date and time, four AER status values and the final link status (`0x43` = 8 GT/s x4, `0x44` = 16 GT/s x4) to `\EFI\Gen3\apply\history.txt` on the ESP (about 100 bytes per boot).

### Requirements

- **Surface Pro 8 + WD SN740** (`15B7:5015`), with the SSD on bus 1 behind root port `00:06.0`. The installer checks this and stops otherwise.
- **Secure Boot off.** The UEFI Shell is not signed by Microsoft, so it will not run with Secure Boot on. Turn it off in Surface UEFI (Volume Up + Power) → Security → Secure Boot. The boot screen then shows a red bar and boot-time malware protection is weaker. **Only use this if you accept that security trade-off.**
- **BitLocker / Device Encryption off or suspended.** Changing the boot path triggers a recovery-key prompt. Running with it on has not been tested.
- Internet access during install (to download the UEFI Shell). Offline, download the same file and pass it with `-ShellPath`.
- If the legacy Windows settings (`windows/auto`) are installed, removing them first with `windows/auto/uninstall.cmd` is recommended.

### Install

In an elevated PowerShell:

```powershell
cd surface-pro-sn740-fix\uefi-gen3-link-cap
powershell -ExecutionPolicy Bypass -File .\Install-Gen3.ps1 -DryRun   # checks and plan only, writes nothing
powershell -ExecutionPolicy Bypass -File .\Install-Gen3.ps1
```

The installer:

1. Downloads `shellx64.efi` from [pbatard/UEFI-Shell](https://github.com/pbatard/UEFI-Shell) 26H1 (edk2-stable202602) and checks SHA256 `4ea080dd…7b11e0`
2. Copies `\EFI\Gen3\shellx64.efi`, `startup.nsh` and `gen3.marker` to the ESP
3. Creates the UEFI boot entry `SN740 Gen3 (UEFI Shell)` (using the device path of an existing Windows entry, with the shell option `-delay 0`) and puts it first in BootOrder; existing entries keep their order
4. Registers the task `SN740 Gen3 Link Check`, which shows a warning at sign-in if the link is not Gen3
5. Backs up the NVRAM boot entries to `%ProgramData%\SN740-Gen3\nvram-backup.json`

After a restart, a black shell screen shows for 1–2 seconds before the usual boot screen. If it ever stops at a `Shell>` prompt, type `exit`.

To make closing the cover on battery go to sleep (if you used hibernate as a workaround):

```powershell
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 1
powercfg /setactive SCHEME_CURRENT
```

### Verify

```powershell
powershell -ExecutionPolicy Bypass -File .\Check-Gen3.ps1
# SN740 link: Gen3 (8 GT/s) - Gen3 cap active
```

In Device Manager → Storage controllers → Standard NVM Express Controller → Details → "PCI current link speed", a value of `3` means the cap is active.

### Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\Uninstall-Gen3.ps1
```

Removes the boot entry, its BootOrder reference, `\EFI\Gen3` on the ESP and the sign-in task. The link returns to Gen4 from the next boot.

### Side effects and limitations

- Boot takes about 1–2 seconds longer (shell start plus retraining).
- If you use rEFInd, lowering `timeout` in `\EFI\refind\refind.conf` (default 20 seconds) makes boot much faster. The test device uses 3 seconds.
- Sequential read is capped at **about 3.5 GB/s** instead of about 5 GB/s (DiskSpd 128K QD32×4: 3,338 MiB/s). Hard to notice in everyday use.
- **Turning Secure Boot back on**, or a firmware / Windows update that changes BootOrder, disables the cap. The sign-in warning then appears. On a boot with that warning, do not close the cover on battery; restart once.
- The shell starts rEFInd, so Linux booted through rEFInd also gets Gen3. Its effect on Linux suspend has not been tested.
- Verified on one device only: Surface Pro 8, WD PC SN740 `SDDPTQE-2T00` firmware `73117000`, Windows 11 25H2 (26200.8457), Surface UEFI 33.106.143.

### Files

| File | Purpose |
|---|---|
| `startup.nsh` | UEFI Shell startup script: Gen3 cap, retrain and boot log (`history.txt`), then the next boot loader |
| `Install-Gen3.ps1` | Install. `-DryRun` only checks |
| `Uninstall-Gen3.ps1` | Uninstall |
| `Check-Gen3.ps1` | Show the current link speed. `-Popup` is used by the sign-in task |
| `UefiBoot.ps1` | Shared helpers for UEFI boot variables and the ESP |
