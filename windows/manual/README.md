# Windows 수동 설치 가이드

Surface Pro 8 + WD SN740 NVMe BSOD 수동 수정 방법입니다.

> **구버전 (2026-10).** 이 설정들로는 Modern Standby 중 리셋이 계속 발생했습니다(PCIe ASPM 끄기 포함). `NoIdleD3`/`NoLPM`은 현재 `stornvme.sys`가 읽지 않는 값입니다. 권장 방법은 [PCIe Gen3 링크 제한](../../uefi-gen3-link-cap/README.md)입니다.

## 문제 원인

- Windows의 **PCIe Link State Power Management**와 **AHCI ASPM**이 NVMe를 저전력 상태로 전환
- 복귀 시 **PCIe Gen 4 링크 트레이닝 실패** → BSOD (`WHEA_UNCORRECTABLE_ERROR`)
- Windows Update가 이 전원 설정을 **기본값으로 되돌림**

## 수동 적용 (powercfg)

관리자 명령 프롬프트 (또는 PowerShell)에서 실행:

```powershell
# 1. AHCI Link Power Management = OFF
powercfg /setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 0b2d69d7-a2a1-449c-9680-f91c70521c60 0
powercfg /setdcvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 0b2d69d7-a2a1-449c-9680-f91c70521c60 0

# 2. PCIe Link State Power Management = OFF
powercfg /setacvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
powercfg /setdcvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0

# 3. NVMe Idle Timeout = 0 (disable)
powercfg /setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 d639518a-e56d-4345-8af2-b9f32fb26109 0
powercfg /setdcvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 d639518a-e56d-4345-8af2-b9f32fb26109 0

# 4. NVMe NOPPME = OFF
powercfg /setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 fc7372b6-ab2d-43ee-8797-15e9841f2cca 0
powercfg /setdcvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 fc7372b6-ab2d-43ee-8797-15e9841f2cca 0

# 5. Apply
powercfg /setactive SCHEME_CURRENT
```

## 수동 적용 (레지스트리)

`files/` 폴더의 `.reg` 파일을 더블클릭하여 적용:

- `disable-pcie-pm.reg` — PCIe/AHCI 전원 관리 비활성화
- `nvme-no-d3.reg` — SN740 NVMe D3 전환 비활성화

## 적용 확인

```powershell
# 현재 AHCI 전원 설정 확인
powercfg /query SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 0b2d69d7-a2a1-449c-9680-f91c70521c60

# 현재 PCIe 링크 상태 확인
powercfg /query SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5
```

두 값 모두 **0x00000000** 이면 정상.

## 주의사항

- Windows Update **후에 매번 다시 실행**해야 합니다
- 자동화하려면 `auto/install.cmd`를 사용하세요
