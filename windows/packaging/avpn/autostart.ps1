# A-VPN start at sign-in, as a scheduled task rather than a Run-key entry: the task fires as soon as the user
# signs in (Run-key apps wait for the desktop and Windows delays them), and with highest privileges, so the
# VPN's TUN mode starts without a UAC prompt. Needs admin rights; the installer and the app's settings run it so.
#   autostart.ps1 -Enable [-User DOMAIN\name]   create or replace the task for that user (default: the current one)
#   autostart.ps1 -Disable                      remove it
param(
    [switch]$Enable,
    [switch]$Disable,
    [string]$User = "$env:USERDOMAIN\$env:USERNAME"
)
$ErrorActionPreference = 'Stop'
$taskName = 'A-VPN'
$exe = Join-Path $PSScriptRoot 'A-VPN.exe'

# the old Run-key entry (written by earlier versions) would start a second copy, or a stale path
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name $taskName -ErrorAction SilentlyContinue
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' -Name $taskName -ErrorAction SilentlyContinue

if ($Disable) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    exit 0
}
if ($Enable) {
    $action = New-ScheduledTaskAction -Execute $exe -Argument '--autostart' -WorkingDirectory $PSScriptRoot
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $User
    $principal = New-ScheduledTaskPrincipal -UserId $User -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -Priority 4 -StartWhenAvailable
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal `
        -Settings $settings -Description 'Starts A-VPN when you sign in' -Force | Out-Null
    exit 0
}
Write-Error 'pass -Enable or -Disable'
exit 1
