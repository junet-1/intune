<#
.SYNOPSIS
    Intune Platform Script: Removes consumer bloatware apps from the device.

.DESCRIPTION
    Removes matching apps twice over: the provisioning (so profiles created later
    never get them) and the installed package for every existing user. Matching is
    done against an explicit pattern list; anything on the protected list is skipped
    even when a pattern would hit it, so a sloppy pattern cannot take out the Store
    or a runtime dependency. Idempotent, safe to run repeatedly. Runs as SYSTEM.

    Apps that Windows installs after the OOBE (WhatsApp, TikTok and the like) come
    from the Consumer Features mechanism. This script cleans up what is already
    there - it does not stop them coming back. That needs the Experience policy
    (Allow Windows Spotlight = Block), which is a configuration profile, not a script.

.NAME
    PS-D-WIN-RemoveConsumerBloat

.RUNAS
    system

.RUN32
    false

.ENFORCESIGNATURE
    false

.NOTES
    Assign as Platform script. Run as SYSTEM (logged-on credentials: No). 64-bit: Yes.
    Platform scripts run once per device - change the file content to make Intune
    run it again. For recurring cleanup use a Remediation instead.
    Exit 0 = finished (individual app failures are logged, not fatal).
#>

$ErrorActionPreference = 'Stop'

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'PS-D-WIN-RemoveConsumerBloat.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

# ---- Apps to remove -----------------------------------------------------------
# Matched with -like against the package name. Verify additions on a reference
# device first:  Get-AppxProvisionedPackage -Online | Select-Object DisplayName
$Targets = @(
    # Store-pushed consumer apps
    '*.WhatsAppDesktop'
    '*TikTok*'
    '*Instagram*'
    'FACEBOOK.*'
    '*.Messenger'
    'SpotifyAB.SpotifyMusic'
    'AmazonVideo.PrimeVideo'
    '*.Netflix'
    'Disney.*'
    '*LinkedInforWindows'
    'king.com.*'
    'ROBLOXCORPORATION.ROBLOX'
    'PicsArt.*'
    '*.AdobeExpress*'
    '*DevHome*'

    # In-box apps
    'Clipchamp.Clipchamp'
    'Microsoft.BingNews'
    'Microsoft.BingWeather'
    'Microsoft.BingSearch'
    'Microsoft.GamingApp'
    'Microsoft.GetHelp'
    'Microsoft.Getstarted'
    'Microsoft.MicrosoftOfficeHub'
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.People'
    'Microsoft.PowerAutomateDesktop'
    'Microsoft.WindowsFeedbackHub'
    'Microsoft.WindowsMaps'
    'Microsoft.YourPhone'
    'Microsoft.ZuneVideo'
    'Microsoft.Xbox.TCUI'
    'Microsoft.XboxGameOverlay'
    'Microsoft.XboxGamingOverlay'
    'Microsoft.XboxIdentityProvider'
    'Microsoft.XboxSpeechToTextOverlay'
    'MicrosoftCorporationII.MicrosoftFamily'
    'MicrosoftTeams'
    'Microsoft.Copilot'
    'Microsoft.549981C3F5F10'          # Cortana
    'Microsoft.Windows.Ai.Copilot.Provider'
)

# ---- Never touch these, whatever the patterns say ------------------------------
$Protected = @(
    'Microsoft.WindowsStore'
    'Microsoft.StorePurchaseApp'
    'Microsoft.DesktopAppInstaller'
    'Microsoft.WindowsTerminal'
    'Microsoft.SecHealthUI'
    'Microsoft.WindowsNotepad'
    'Microsoft.Paint'
    'Microsoft.ScreenSketch'
    'Microsoft.WindowsCalculator'
    'Microsoft.WindowsCamera'
    'Microsoft.Windows.Photos'
    'Microsoft.UI.Xaml.*'
    'Microsoft.VCLibs.*'
    'Microsoft.NET.*'
    'Microsoft.Services.Store.Engagement'
    'Microsoft.WindowsAppRuntime.*'
    'MicrosoftWindows.Client.*'
    'Microsoft.Windows.ShellExperienceHost'
    'Microsoft.Windows.StartMenuExperienceHost'
    'Microsoft.AAD.BrokerPlugin'
    'Microsoft.AccountsControl'
    'Microsoft.CompanyPortal'
    'Microsoft.RemoteDesktop'
    'Windows.*'
)

function Test-Match {
    param([string]$Name, [string[]]$Patterns)
    foreach ($p in $Patterns) { if ($Name -like $p) { return $true } }
    return $false
}

Write-Log "=== PS-D-WIN-RemoveConsumerBloat started ==="
$removed = 0
$failed = 0

# ---- 1. Provisioning: keeps them out of profiles created later -----------------
try {
    $provisioned = Get-AppxProvisionedPackage -Online
    Write-Log ("Provisioned packages found: {0}" -f $provisioned.Count)
} catch {
    Write-Log "FATAL: could not enumerate provisioned packages: $_"
    exit 1
}

foreach ($pkg in $provisioned) {
    $name = $pkg.DisplayName
    if (-not (Test-Match $name $Targets)) { continue }
    if (Test-Match $name $Protected) { Write-Log "  protected, skipping: $name"; continue }

    try {
        $null = Remove-AppxProvisionedPackage -Online -AllUsers -PackageName $pkg.PackageName -ErrorAction Stop
        Write-Log "  deprovisioned: $name"
        $removed++
    } catch {
        Write-Log "  FAILED to deprovision ${name}: $($_.Exception.Message)"
        $failed++
    }
}

# ---- 2. Installed packages: cleans up existing profiles ------------------------
try {
    $installed = Get-AppxPackage -AllUsers
    Write-Log ("Installed packages found: {0}" -f $installed.Count)
} catch {
    Write-Log "Could not enumerate installed packages: $_"
    $installed = @()
}

foreach ($pkg in $installed) {
    $name = $pkg.Name
    if (-not (Test-Match $name $Targets)) { continue }
    if (Test-Match $name $Protected) { Write-Log "  protected, skipping: $name"; continue }
    if ($pkg.NonRemovable) { Write-Log "  not removable, skipping: $name"; continue }

    try {
        Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
        Write-Log "  removed: $($pkg.PackageFullName)"
        $removed++
    } catch {
        Write-Log "  FAILED to remove $($pkg.PackageFullName): $($_.Exception.Message)"
        $failed++
    }
}

Write-Log "=== Finished. Removed: $removed, failed: $failed ==="
exit 0

