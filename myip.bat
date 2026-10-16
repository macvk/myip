@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Public IP address client for bash.ws.
rem Project: https://github.com/macvk/myip
rem SPDX-License-Identifier: MIT

set "api_domain=bash.ws"
set "random_suffix=%RANDOM%-%RANDOM%"
set "all_list=%TEMP%\myip-%random_suffix%-all.tmp"
set "ipv4_list=%TEMP%\myip-%random_suffix%-ipv4.tmp"
set "ipv6_list=%TEMP%\myip-%random_suffix%-ipv6.tmp"
set "ipv4_count=0"
set "ipv6_count=0"

where curl.exe >nul 2>&1

if errorlevel 1 (
    echo My IP failed: curl.exe is required.>&2
    exit /b 1
)

type nul > "%all_list%"
type nul > "%ipv4_list%"
type nul > "%ipv6_list%"

for /f "usebackq delims=" %%I in (`curl.exe --silent --show-error --fail --max-time 10 "https://ipv4.%api_domain%/" 2^>nul`) do call :add_address 4 "%%I"

for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "Get-NetIPAddress -AddressFamily IPv4 ^| Where-Object { $_.AddressState -eq 'Preferred' -and $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } ^| Select-Object -ExpandProperty IPAddress" 2^>nul`) do (
    for /f "usebackq delims=" %%A in (`curl.exe --silent --show-error --fail --max-time 10 --interface "%%I" "https://ipv4.%api_domain%/" 2^>nul`) do call :add_address 4 "%%A"
)

for /f "usebackq delims=" %%I in (`curl.exe --silent --show-error --fail --max-time 10 "https://ipv6.%api_domain%/" 2^>nul`) do call :add_address 6 "%%I"

for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "Get-NetIPAddress -AddressFamily IPv6 ^| Where-Object { $_.AddressState -eq 'Preferred' -and $_.IPAddress -ne '::1' -and $_.IPAddress -notlike 'fe80:*' } ^| Select-Object -ExpandProperty IPAddress" 2^>nul`) do (
    for /f "usebackq delims=" %%A in (`curl.exe --silent --show-error --fail --max-time 10 --interface "%%I" "https://ipv6.%api_domain%/" 2^>nul`) do call :add_address 6 "%%A"
)

if %ipv4_count% == 0 if %ipv6_count% == 0 (
    echo My IP failed: no public IPv4 or IPv6 address was detected.>&2
    call :cleanup
    exit /b 1
)

if not %ipv4_count% == 0 (
    echo Your IPv4:
    type "%ipv4_list%"
    if %ipv4_count% == 1 (
        echo Found IPv4: 1 address
    ) else (
        echo Found IPv4: %ipv4_count% addresses
    )
)

if not %ipv4_count% == 0 if not %ipv6_count% == 0 echo(

if not %ipv6_count% == 0 (
    echo Your IPv6:
    type "%ipv6_list%"
    if %ipv6_count% == 1 (
        echo Found IPv6: 1 address
    ) else (
        echo Found IPv6: %ipv6_count% addresses
    )
)

call :cleanup
exit /b 0

:add_address
set "family=%~1"
set "address=%~2"

powershell -NoProfile -Command "try { $ip = [Net.IPAddress]::Parse($env:address); if (($env:family -eq '4' -and $ip.AddressFamily -ne 'InterNetwork') -or ($env:family -eq '6' -and $ip.AddressFamily -ne 'InterNetworkV6')) { exit 1 } } catch { exit 1 }" >nul 2>&1

if errorlevel 1 exit /b 0

findstr /x /l /c:"%address%" "%all_list%" >nul 2>&1

if not errorlevel 1 exit /b 0

>> "%all_list%" echo %address%
set "details="

for /f "tokens=1-5 delims=|" %%A in ('curl.exe --silent --show-error --fail --max-time 10 "https://%api_domain%/geoiplookup/%address%?embed=txt" 2^>nul') do (
    set "country=%%B"

    if defined country (
        if not "%%E" == "" (
            set "details=%address% [%%D, %%C, !country!, %%E]"
        ) else if not "%%D" == "" (
            set "details=%address% [%%C, !country!, %%D]"
        ) else if not "%%C" == "" (
            set "details=%address% [!country!, %%C]"
        ) else (
            set "details=%address% [!country!]"
        )
    )
)

if not defined details set "details=%address%"

if "%family%" == "4" (
    >> "%ipv4_list%" echo !details!
    set /a ipv4_count+=1
) else (
    >> "%ipv6_list%" echo !details!
    set /a ipv6_count+=1
)

exit /b 0

:cleanup
del /q "%all_list%" "%ipv4_list%" "%ipv6_list%" >nul 2>&1
exit /b 0
