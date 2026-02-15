@echo off
:: ============================================================
:: SN740 PCIe Fix — Automated Installer (Windows)
:: Run as Administrator
:: ============================================================

:: ── Admin check ─────────────────────────────────────────
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] 관리자 권한이 필요합니다.
    echo         이 파일을 우클릭하고 "관리자 권한으로 실행"을 선택하세요.
    pause
    exit /b 1
)

echo ============================================
echo  SN740 PCIe BSOD Fix - Auto Installer
echo ============================================
echo.

set "INSTALL_DIR=%SystemRoot%\System32\SN740Fix"
set "SCRIPT_DIR=%~dp0"

:: ── 1. Copy scripts to System32 ─────────────────────────
echo [1/4] 스크립트 설치 중...
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

copy /Y "%SCRIPT_DIR%scripts\fix-pcie-power.ps1" "%INSTALL_DIR%\fix-pcie-power.ps1" >nul
copy /Y "%SCRIPT_DIR%scripts\SN740-PCIe-Fix.xml" "%INSTALL_DIR%\SN740-PCIe-Fix.xml" >nul
echo      %INSTALL_DIR% 에 설치 완료
echo.

:: ── 2. Apply powercfg immediately ───────────────────────
echo [2/4] PCIe 전원 설정 즉시 적용 중...
powershell -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_DIR%\fix-pcie-power.ps1"
echo.

:: ── 3. Register scheduled task ──────────────────────────
echo [3/4] 스케줄 태스크 등록 중...
schtasks /create /xml "%INSTALL_DIR%\SN740-PCIe-Fix.xml" /tn "SN740-PCIe-Fix" /f >nul 2>&1
if %errorLevel% equ 0 (
    echo      스케줄 태스크 등록 완료 (부팅 시 + Windows Update 후 자동 실행)
) else (
    echo      XML 등록 실패, 기본 방식으로 등록...
    schtasks /create /tn "SN740-PCIe-Fix" /tr "powershell -NoProfile -ExecutionPolicy Bypass -File \"%INSTALL_DIR%\fix-pcie-power.ps1\"" /sc onstart /ru SYSTEM /rl highest /f >nul 2>&1
    if %errorLevel% equ 0 (
        echo      스케줄 태스크 등록 완료 (부팅 시 자동 실행)
    ) else (
        echo      [WARNING] 태스크 등록 실패
    )
)
echo.

:: ── 4. Verify ───────────────────────────────────────────
echo [4/4] 확인 중...
schtasks /query /tn "SN740-PCIe-Fix" /fo list 2>nul | findstr /i "TaskName Status"
echo.

echo ============================================
echo  설치 완료!
echo.
echo  - 매 부팅 시 자동 적용
echo  - Windows Update 후 자동 재적용
echo  - 로그: %INSTALL_DIR%\fix-pcie-power.log
echo ============================================
echo.
pause
