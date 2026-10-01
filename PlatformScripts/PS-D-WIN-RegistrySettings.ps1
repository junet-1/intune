<#
.SYNOPSIS
    Intune Platform Script: Configure machine-wide registry settings.

.DESCRIPTION
    Creates or updates registry values defined in $RegistrySettings.
    Intended for settings without a suitable Settings Catalog / CSP equivalent.
    Runs as SYSTEM and is idempotent.

.NAME
    PS-D-WIN-RegistrySettings

.RUNAS
    system

.RUN32
    false

.ENFORCESIGNATURE
    false

.NOTES
    Assign as Platform script. Run as SYSTEM (logged-on credentials: No). 64-bit: Yes.
    Exit 0 = success.
    Exit 1 = one or more registry settings failed.
#>

$ErrorActionPreference = 'Stop'

# -------------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------------

$RegistrySettings = @(
    @{
        Path  = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'
        Name  = 'DefaultSearchProviderSearchURL'
        Type  = 'String'
        Value = '{google:baseURL}search?q=%s&{google:RLZ}{google:originalQueryForSuggestion}{google:assistedQueryStats}{google:searchboxStats}{google:searchFieldtrialParameter}{google:language}{google:prefetchSource}{google:searchClient}{google:sourceId}{google:searchSource}{google:contextualSearchVersion}ie={inputEncoding}'
    }

    # Examples:
    # @{
    #     Path  = 'HKLM:\SOFTWARE\Contoso'
    #     Name  = 'Enabled'
    #     Type  = 'DWord'
    #     Value = 1
    # }
    #
    # @{
    #     Path  = 'HKLM:\SOFTWARE\Contoso'
    #     Name  = 'InstallPath'
    #     Type  = 'ExpandString'
    #     Value = '%ProgramFiles%\Contoso'
    # }
)

# -------------------------------------------------------------------------------
# Logging
# -------------------------------------------------------------------------------

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'PS-D-WIN-RegistrySettings.log'

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $Entry = '{0} {1}' -f (Get-Date -Format u), $Message
    Add-Content -Path $Log -Value $Entry
    Write-Output $Message
}

# -------------------------------------------------------------------------------
# Registry
# -------------------------------------------------------------------------------

function Set-RegistrySetting {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord')]
        [string]$Type,

        [Parameter(Mandatory)]
        $Value
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        $null = New-Item -Path $Path -Force
        Write-Log "Created registry key: $Path"
    }

    $CurrentValue = $null
    $ValueExists = $false

    try {
        $CurrentValue = Get-ItemPropertyValue -LiteralPath $Path -Name $Name -ErrorAction Stop
        $ValueExists = $true
    }
    catch [System.Management.Automation.PSArgumentException] {
        $ValueExists = $false
    }

    $ValueMatches = $false

    if ($ValueExists) {
        if ($Type -eq 'MultiString') {
            $ValueMatches = ($CurrentValue -join "`0") -ceq ($Value -join "`0")
        }
        elseif ($Type -eq 'Binary') {
            $ValueMatches = ([Convert]::ToBase64String($CurrentValue) -ceq [Convert]::ToBase64String($Value))
        }
        else {
            $ValueMatches = $CurrentValue -ceq $Value
        }
    }

    if ($ValueMatches) {
        Write-Log "Compliant: $Path\$Name"
        return
    }

    New-ItemProperty -LiteralPath $Path -Name $Name -PropertyType $Type -Value $Value -Force | Out-Null
    Write-Log "Configured: $Path\$Name = $Value [$Type]"
}

# -------------------------------------------------------------------------------
# Main
# -------------------------------------------------------------------------------

Write-Log '=== PS-D-WIN-RegistrySettings started ==='

$Failed = $false

foreach ($Setting in $RegistrySettings) {
    try {
        Set-RegistrySetting -Path $Setting.Path -Name $Setting.Name -Type $Setting.Type -Value $Setting.Value
    }
    catch {
        $Failed = $true
        Write-Log "FAILED: $($Setting.Path)\$($Setting.Name) - $($_.Exception.Message)"
    }
}

if ($Failed) {
    Write-Log '=== Finished with errors ==='
    exit 1
}

Write-Log '=== Finished successfully ==='
exit 0
