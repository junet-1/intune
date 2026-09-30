<#
.SYNOPSIS
    Intune Remediation - Remediation: Reminds the user to restart the device.

.DESCRIPTION
    Shows a toast (falling back to a message box) asking the user to restart when
    the device has been up too long. It deliberately does NOT reboot - a field
    device must never be restarted without the user's action.

.NAME
    Reboot Reminder (Uptime)

.RUNAS
    user

.NOTES
    Runs in the USER context. Uses Windows PowerShell 5.1 (WinRT toast); Intune
    runs scripts in 5.1 by default. Exit 0 = reminder shown (or nothing to do).
#>

#region ---- Configuration (keep identical in Detect + Remediate) ---------------
$MaxUptimeDays = 7
#endregion ----------------------------------------------------------------------

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'Remediate-UptimeReboot.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

function Show-Reminder {
    param([string]$Title, [string]$Message)
    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.UI.Notifications.ToastNotification,        Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        $xml   = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        $texts = $xml.GetElementsByTagName('text')
        $texts.Item(0).AppendChild($xml.CreateTextNode($Title))   | Out-Null
        $texts.Item(1).AppendChild($xml.CreateTextNode($Message)) | Out-Null
        $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Microsoft.Windows.Explorer').Show($toast)
        return $true
    }
    catch {
        # Fallback: message box via msg.exe (present on Pro/Enterprise).
        try { & "$env:WINDIR\System32\msg.exe" * "/TIME:600" "$Title - $Message"; return $true }
        catch { return $false }
    }
}

try {
    $boot = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime
    $days = [int]((Get-Date) - $boot).TotalDays

    if ($days -le $MaxUptimeDays) {
        Write-Log "Nothing to do: uptime is $days days."
        exit 0
    }

    $shown = Show-Reminder -Title 'Neustart empfohlen' `
        -Message "Dieses Gerät läuft seit $days Tagen ohne Neustart. Bitte bei Gelegenheit neu starten."
    if ($shown) {
        Write-Log "Reminder shown (uptime $days days)."
    } else {
        Write-Log "WARN: could not show reminder (uptime $days days)."
    }
    exit 0
}
catch {
    Write-Log "ERROR during remediation: $($_.Exception.Message)"
    exit 1
}

