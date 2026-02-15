@echo off
:: ============================================================
:: SN740 PCIe Fix — Uninstaller (Windows)
:: Run as Administrator
:: ============================================================

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] 관리자 권한이 필요합니다.
    pause
    exit /b 1
)

echo ============================================
echo  SN740 PCIe Fix - Uninstaller
echo ============================================
echo.

:: 1. Remove scheduled task
echo [1/3] 스케줄 태스크 제거 중...
schtasks /delete /tn "SN740-PCIe-Fix" /f >nul 2>&1
if %errorLevel% equ 0 (
    echo      스케줄 태스크 제거 완료
) else (
    echo      스케줄 태스크 없음 (스킵)
)
echo.

:: 2. Remove installed files
echo [2/3] 설치된 파일 제거 중...
set "INSTALL_DIR=%SystemRoot%\System32\SN740Fix"
if exist "%INSTALL_DIR%" (
    rmdir /s /q "%INSTALL_DIR%"
    echo      %INSTALL_DIR% 제거 완료
) else (
    echo      설치 폴더 없음 (스킵)
)
echo.

:: 3. Restore default power settings
echo [3/3] 전원 설정 기본값 복원 중...
powercfg /setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 0b2d69d7-a2a1-449c-9680-f91c70521c60 1
powercfg /setdcvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 0b2d69d7-a2a1-449c-9680-f91c70521c60 1
powercfg /setacvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 1
powercfg /setdcvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 1
powercfg /setactive SCHEME_CURRENT
echo      전원 설정 기본값 복원 완료
echo.

echo ============================================
echo  제거 완료! 재부팅이 필요합니다.
echo ============================================
echo.
pause
