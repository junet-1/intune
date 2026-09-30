<#
.SYNOPSIS
    Intune Platform Script: Turns on the firmware security features of the
    baseline over the BIOS interface of the respective manufacturer.

.DESCRIPTION
    Detects the manufacturer and talks to its BIOS WMI provider:

      Dell    root\dcim\sysman\biosattributes (agent-free WMI-ACPI) or, as a
              fallback, root\dell\sysman from Dell Command | Monitor
      HP      root\hp\instrumentedBIOS (HP_BIOSSettingInterface)
      Lenovo  root\wmi (Lenovo_SetBiosSetting + Lenovo_SaveBiosSettings)

    The feature table below drives everything. Per feature the script reads the
    current value, leaves it alone when it is already on and switches it on when
    it is off. Only features that carry no operational risk are in the table -
    nothing here changes how a device boots, and nothing clears a TPM.

    Attribute names differ per vendor and per model, so none is hardcoded: the
    script enumerates what the firmware exposes, takes the first hit from the
    vendor candidate list and falls back to a pattern match over the remaining
    names. Names that would trigger a destructive action (clear, reset, erase
    and the like) are excluded from matching throughout. The value to write is
    picked from the attribute's own list of possible values, which covers the
    Enabled/Enable/Active/Available spelling differences between vendors.

    A feature the model does not expose is logged and skipped. Only TXT is
    marked as required, because it is the point of the run: some firmwares hide
    it until VT-x and VT-d are on, so the first run enables those, exits 1, and
    the Intune retry after the restart finds TXT and finishes the job.

    A firmware change of this kind alters the PCR measurements, which sends a
    protected device into BitLocker recovery on the next boot. Protection on the
    OS drive is therefore suspended for one reboot before anything is written.

    Idempotent: a run that has nothing to do writes nothing and suspends
    nothing. The settings become active with the next restart.

.NAME
    PS-D-WIN-BiosBaseline

.RUNAS
    system

.RUN32
    false

.ENFORCESIGNATURE
    false

.NOTES
    Assign as Platform script. Run as SYSTEM (logged-on credentials: No). 64-bit: Yes.
    Restart required - schedule one separately.
    Set $BiosPassword when a BIOS admin/setup password is set, otherwise the
    firmware rejects every write.
    Exit 0 = everything on or nothing to do, 1 = no provider, a required feature
    missing or a write failed (Intune retries).
#>

# ---- Configuration ------------------------------------------------------------

# BIOS admin/setup password, empty when none is set
$BiosPassword = ''

# Suspend BitLocker for one reboot before writing, so the PCR change does not
# trigger recovery
$SuspendBitLockerFirst = $true

# The baseline. Order matters: VT-d before VT-x so the broader virtualization
# pattern cannot claim the VT-d attribute, prerequisites before TXT.
# Names are tried in order, Pattern is the fallback, empty Pattern means the
# candidate list is final.
$Features = @(
    [pscustomobject]@{
        Key      = 'VT-d'
        Required = $false
        Pattern  = '(?i)vt[ _-]?d|directed[ _]?i/?o'
        Names    = @{
            Dell   = @('VtForDirectIo', 'VtForDirectIO')
            HP     = @('Virtualization Technology for Directed I/O (VTd)', 'Virtualization Technology Directed I/O (VTd)')
            Lenovo = @('VTdFeature', 'Intel(R) VT-d Feature')
        }
    }
    [pscustomobject]@{
        Key      = 'VT-x'
        Required = $false
        Pattern  = '(?i)virtuali[sz]ation'
        Names    = @{
            Dell   = @('VirtualizationEnable', 'Virtualization')
            HP     = @('Virtualization Technology (VTx)', 'Virtualization Technology', 'Intel (R) Virtualization Technology')
            Lenovo = @('VirtualizationTechnology', 'Intel(R) Virtualization Technology')
        }
    }
    [pscustomobject]@{
        Key      = 'TPM'
        Required = $false
        Pattern  = '(?i)^tpm( device| state)?$|security ?chip'
        Names    = @{
            Dell   = @('TpmSecurity', 'TpmActivation')
            HP     = @('TPM Device', 'TPM State', 'Embedded Security Device Availability')
            Lenovo = @('SecurityChip', 'Security Chip')
        }
    }
    [pscustomobject]@{
        # Dell and HP split the TPM in two: the chip is made visible first, then
        # switched on. The row above takes the visibility attribute, this one
        # the state that follows it.
        Key      = 'TPM state'
        Required = $false
        Pattern  = ''
        Names    = @{
            Dell   = @('TpmActivation')
            HP     = @('TPM State', 'Embedded Security Device')
            Lenovo = @()
        }
    }
    [pscustomobject]@{
        Key      = 'DMA protection'
        Required = $false
        Pattern  = '(?i)dma'
        Names    = @{
            Dell   = @('KernelDmaProtection', 'PreBootDmaSupport', 'DmaProtection')
            HP     = @('Pre-boot DMA protection', 'DMA Protection', 'Kernel DMA Protection')
            Lenovo = @('KernelDMAProtection', 'PreBootDMAProtection')
        }
    }
    [pscustomobject]@{
        Key      = 'SMM mitigation'
        Required = $false
        Pattern  = '(?i)smm'
        Names    = @{
            Dell   = @('SmmSecurityMitigation')
            HP     = @('SMM Security Mitigation')
            Lenovo = @('SMMSecurityMitigation')
        }
    }
    [pscustomobject]@{
        Key      = 'Memory encryption'
        Required = $false
        Pattern  = '(?i)memory ?encryption'
        Names    = @{
            Dell   = @('TotalMemoryEncryption', 'MemoryEncryption')
            HP     = @('Total Memory Encryption (TME)', 'Total Memory Encryption')
            Lenovo = @('TotalMemoryEncryption')
        }
    }
    [pscustomobject]@{
        Key      = 'Intel TXT'
        Required = $true
        Pattern  = '(?i)trusted[ _-]?execution|(^|[^a-z])txt([^a-z]|$)'
        Names    = @{
            Dell   = @('TrustedExecution', 'IntelTxt', 'TxtSupport', 'Txt')
            HP     = @('Intel(R) TXT', 'Trusted Execution Technology (TXT)', 'Intel(R) Trusted Execution Technology', 'TXT')
            Lenovo = @('TXTFeature', 'IntelTXTFeature', 'Intel(R) TXT Feature', 'TXT')
        }
    }
)

# Never resolve to an attribute whose name says it does something destructive -
# a pattern like ^tpm would otherwise be free to land on a clear-TPM switch
$UnsafePattern = '(?i)clear|erase|wipe|reset|revoke|physical ?presence|\bppi\b|password'

$LogDir = 'C:\ProgramData\IntuneScripts\Logs'
$null = New-Item -ItemType Directory -Path $LogDir -Force
$Log = Join-Path $LogDir 'PS-D-WIN-BiosBaseline.log'
function Write-Log { param($m) Add-Content -Path $Log -Value ('{0} {1}' -f (Get-Date -Format u), $m); Write-Output $m }

Write-Log '=== PS-D-WIN-BiosBaseline started ==='

# ---- Helpers ------------------------------------------------------------------

# Every vendor spells the two states differently, and the TPM ones do not even
# use the same words as the rest
function ConvertTo-State {
    param([string]$Value)
    switch -Regex ("$Value".Trim()) {
        '^(enable|enabled|on|1|yes|active|available)$'      { 'Enabled';  break }
        '^(disable|disabled|off|0|no|inactive|hidden)$'      { 'Disabled'; break }
        default                                              { $null }
    }
}

function Resolve-Attribute {
    param($Attributes, [string[]]$Candidates, [string]$Pattern, [string[]]$Exclude = @())
    $pool = $Attributes | Where-Object { $_.Name -notmatch $script:UnsafePattern -and $Exclude -notcontains $_.Name }
    foreach ($c in $Candidates) {
        $hit = $pool | Where-Object { $_.Name -eq $c } | Select-Object -First 1
        if ($hit) { return $hit }
    }
    if (-not $Pattern) { return $null }
    $pool | Where-Object { $_.Name -match $Pattern } | Select-Object -First 1
}

# The spelling the firmware itself uses for "on"
function Get-EnabledValue {
    param($Attribute)
    foreach ($p in @($Attribute.Possible)) {
        if ((ConvertTo-State $p) -eq 'Enabled') { return $p }
    }
    if ($script:Vendor -eq 'Dell') { 'Enabled' } else { 'Enable' }
}

# Not every provider reports this, and a missing answer must not stop the run
function Test-ReadOnly {
    param($Attribute)
    $Attribute.ReadOnly -eq $true
}

function Get-Property {
    param($Instance, [string]$Name)
    $p = $Instance.PSObject.Properties[$Name]
    if ($p) { $p.Value } else { $null }
}

# ---- Vendor detection ---------------------------------------------------------

$cs   = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1

$Vendor = switch -Regex ("$($cs.Manufacturer)") {
    'Dell'                { 'Dell';   break }
    'HP|Hewlett[- ]?Pack' { 'HP';     break }
    'Lenovo'              { 'Lenovo'; break }
    default               { 'Unknown' }
}

Write-Log "Device: $($cs.Manufacturer) $($cs.Model), BIOS $($bios.SMBIOSBIOSVersion), CPU $($cpu.Name)"
Write-Log "Vendor path: $Vendor"

if ("$($cpu.Manufacturer)" -notmatch 'Intel|GenuineIntel') {
    Write-Log 'Nothing to do: this baseline covers Intel platforms and this is not an Intel CPU.'
    exit 0
}

if ($Vendor -eq 'Unknown') {
    Write-Log "ERROR: no BIOS interface known for manufacturer '$($cs.Manufacturer)'."
    exit 1
}

# ---- Reading the attributes ---------------------------------------------------

$DellPath        = $null
$LenovoNeedsSave = $false

function Get-BiosAttributes {
    switch ($script:Vendor) {

        'Dell' {
            # Agent-free WMI-ACPI first, it is present on current business models.
            # Note the property is PossibleValue, singular, unlike the other providers.
            $native = Get-CimInstance -Namespace 'root\dcim\sysman\biosattributes' -ClassName EnumerationAttribute -ErrorAction Ignore
            if ($native) {
                $script:DellPath = 'Native'
                return $native | ForEach-Object {
                    [pscustomobject]@{
                        Name     = $_.AttributeName
                        Current  = @($_.CurrentValue)[0]
                        Possible = @($_.PossibleValue)
                        ReadOnly = (Get-Property $_ 'IsReadOnly') -eq $true
                    }
                }
            }
            # Dell Command | Monitor as fallback - reports value codes, the
            # readable text sits in PossibleValuesDescription
            $dcm = Get-CimInstance -Namespace 'root\dell\sysman' -ClassName DCIM_BIOSEnumeration -ErrorAction Ignore
            if ($dcm) {
                $script:DellPath = 'Monitor'
                return $dcm | ForEach-Object {
                    $values = @($_.PossibleValues)
                    $texts  = @($_.PossibleValuesDescription)
                    $code   = @($_.CurrentValue)[0]
                    $idx    = [array]::IndexOf($values, $code)
                    [pscustomobject]@{
                        Name     = $_.AttributeName
                        Current  = if ($idx -ge 0 -and $texts.Count -gt $idx) { $texts[$idx] } else { "$code" }
                        Possible = if ($texts.Count) { $texts } else { $values }
                        ReadOnly = (Get-Property $_ 'IsReadOnly') -eq $true
                    }
                }
            }
        }

        'HP' {
            $hp = Get-CimInstance -Namespace 'root\hp\instrumentedBIOS' -ClassName HP_BIOSEnumeration -ErrorAction Ignore
            if ($hp) {
                return $hp | ForEach-Object {
                    [pscustomobject]@{
                        Name     = $_.Name
                        Current  = @($_.CurrentValue)[0]
                        Possible = @($_.PossibleValues)
                        ReadOnly = (Get-Property $_ 'IsReadOnly') -in @(1, $true)
                    }
                }
            }
        }

        'Lenovo' {
            $lv = Get-CimInstance -Namespace 'root\wmi' -ClassName Lenovo_BiosSetting -ErrorAction Ignore
            if ($lv) {
                return $lv | Where-Object { $_.CurrentSetting } | ForEach-Object {
                    # CurrentSetting is "Name,Value", sometimes with ";[Optional:...]" appended
                    $parts = (("$($_.CurrentSetting)" -split ';')[0]) -split ','
                    if ($parts.Count -lt 2) { return }
                    [pscustomobject]@{
                        Name     = $parts[0]
                        Current  = $parts[1]
                        Possible = @()   # filled on demand via Lenovo_GetBiosSelections
                        ReadOnly = $false
                    }
                }
            }
        }
    }
    return $null
}

# Lenovo does not report the possible values with the setting itself
function Add-LenovoSelections {
    param($Attribute)
    if (-not $Attribute -or $script:Vendor -ne 'Lenovo') { return $Attribute }
    try {
        $sel = Invoke-CimMethod -Namespace 'root\wmi' -ClassName Lenovo_GetBiosSelections `
            -MethodName GetBiosSelections -Arguments @{ Item = $Attribute.Name } -ErrorAction Stop
        if ($sel.Selections) { $Attribute.Possible = @("$($sel.Selections)" -split ',') }
    } catch {
        Write-Log "  could not read selections for $($Attribute.Name): $($_.Exception.Message)"
    }
    $Attribute
}

# ---- Writing ------------------------------------------------------------------

function Set-BiosAttribute {
    param([string]$Name, [string]$Value)

    switch ($script:Vendor) {

        'Dell' {
            if ($script:DellPath -eq 'Native') {
                # The password goes in as a byte array, with SecType 1 marking it
                # as plain text; SecType 0 and an empty array mean no password
                $bytes = if ($BiosPassword) { (New-Object System.Text.UTF8Encoding).GetBytes($BiosPassword) } else { @() }
                $iface = Get-CimInstance -Namespace 'root\dcim\sysman\biosattributes' -ClassName BIOSAttributeInterface -ErrorAction Stop
                $r = Invoke-CimMethod -InputObject $iface -MethodName SetAttribute -Arguments @{
                    SecType        = [uint32]$(if ($BiosPassword) { 1 } else { 0 })
                    SecHndCount    = [uint32]$bytes.Length
                    SecHandle      = [byte[]]$bytes
                    AttributeName  = $Name
                    AttributeValue = $Value
                } -ErrorAction Stop
                if ($r.Status -eq 0) { return $true }
                Write-Log "  provider returned status $($r.Status)"
                return $false
            }

            $svc = Get-CimInstance -Namespace 'root\dell\sysman' -ClassName DCIM_BIOSService -ErrorAction Stop
            $arguments = @{ AttributeName = @($Name); AttributeValue = @($Value) }
            if ($BiosPassword) { $arguments['AuthorizationToken'] = $BiosPassword }
            $r = Invoke-CimMethod -InputObject $svc -MethodName SetBIOSAttributes `
                -Arguments $arguments -ErrorAction Stop
            if ($r.ReturnValue -eq 0) { return $true }
            Write-Log "  provider returned $($r.ReturnValue)"
            return $false
        }

        'HP' {
            # HP wants the password prefixed with the encoding marker
            $pw = if ($BiosPassword) { "<utf-16/>$BiosPassword" } else { '' }
            $iface = Get-CimInstance -Namespace 'root\hp\instrumentedBIOS' -ClassName HP_BIOSSettingInterface -ErrorAction Stop
            $r = Invoke-CimMethod -InputObject $iface -MethodName SetBIOSSetting `
                -Arguments @{ Name = $Name; Value = $Value; Password = $pw } -ErrorAction Stop
            $rc = if ($null -ne $r.Return) { $r.Return } else { $r.ReturnValue }
            if ($rc -eq 0) { return $true }
            Write-Log "  provider returned $rc"
            return $false
        }

        'Lenovo' {
            $arg = if ($BiosPassword) { "$Name,$Value,$BiosPassword,ascii,us" } else { "$Name,$Value" }
            $set = Get-CimInstance -Namespace 'root\wmi' -ClassName Lenovo_SetBiosSetting -ErrorAction Stop
            $r = Invoke-CimMethod -InputObject $set -MethodName SetBiosSetting `
                -Arguments @{ parameter = $arg } -ErrorAction Stop
            if ("$($r.return)" -eq 'Success') {
                $script:LenovoNeedsSave = $true
                return $true
            }
            Write-Log "  provider returned $($r.return)"
            return $false
        }
    }
    return $false
}

# Lenovo keeps the writes pending until they are saved once at the end
function Save-LenovoSettings {
    $arg = if ($BiosPassword) { "$BiosPassword,ascii,us" } else { '' }
    $save = Get-CimInstance -Namespace 'root\wmi' -ClassName Lenovo_SaveBiosSettings -ErrorAction Stop
    $r = Invoke-CimMethod -InputObject $save -MethodName SaveBiosSettings `
        -Arguments @{ parameter = $arg } -ErrorAction Stop
    if ("$($r.return)" -eq 'Success') { return $true }
    Write-Log "  save returned $($r.return)"
    return $false
}

# ---- Plan ---------------------------------------------------------------------

$attributes = Get-BiosAttributes
if (-not $attributes) {
    Write-Log "ERROR: no BIOS attributes readable for $Vendor. Dell needs a model with agent-free WMI-ACPI or Dell Command | Monitor, HP the BIOS WMI provider, Lenovo a firmware exposing root\wmi."
    exit 1
}
Write-Log "Read $(@($attributes).Count) BIOS attributes$(if ($DellPath) { " over the $DellPath path" })."

# Dell reports whether a setup password is set, so say so up front instead of
# letting the write fail with an opaque status
if ($DellPath -eq 'Native' -and -not $BiosPassword) {
    $pwSet = Get-CimInstance -Namespace 'root\dcim\sysman\wmisecurity' -ClassName PasswordObject -ErrorAction Ignore |
        Where-Object NameId -eq 'Admin' | Select-Object -ExpandProperty IsPasswordSet -First 1
    if ($pwSet -eq 1) {
        Write-Log 'ERROR: a BIOS admin password is set but $BiosPassword is empty - the firmware would reject every write.'
        exit 1
    }
}

$plan    = @()
$used    = @()
$missing = @()

foreach ($f in $Features) {
    $attr = Add-LenovoSelections (Resolve-Attribute $attributes $f.Names[$Vendor] $f.Pattern -Exclude $used)

    if (-not $attr) {
        $missing += $f
        Write-Log "$($f.Key): not exposed by this model"
        continue
    }
    $used += $attr.Name

    $state = ConvertTo-State $attr.Current
    Write-Log "$($f.Key): $($attr.Name) = $($attr.Current)$(if ($state) { " ($state)" } else { ' (state not recognised)' })"

    if ($state -eq 'Enabled') { continue }

    if (Test-ReadOnly $attr) {
        Write-Log "  read-only, skipped"
        continue
    }
    if (-not $state) {
        # Leave anything the script cannot read as on or off untouched rather
        # than guessing at a third state
        Write-Log "  value is neither on nor off, skipped"
        continue
    }

    $plan += [pscustomobject]@{ Key = $f.Key; Name = $attr.Name; Value = (Get-EnabledValue $attr) }
}

$requiredMissing = @($missing | Where-Object Required)
if ($requiredMissing) {
    Write-Log "Required feature(s) not exposed: $((@($requiredMissing | ForEach-Object Key) -join ', '))"
}

if (-not $plan) {
    if ($requiredMissing) {
        Write-Log '=== Finished: nothing to write, but a required feature is missing - the firmware may hide it until a restart ==='
        exit 1
    }
    Write-Log '=== Finished: everything already on ==='
    exit 0
}

Write-Log "Planned: $((@($plan | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ', '))"

# ---- Apply --------------------------------------------------------------------

if ($SuspendBitLockerFirst) {
    try {
        $vol = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
        if ($vol.ProtectionStatus -eq 'On') {
            Suspend-BitLocker -MountPoint $env:SystemDrive -RebootCount 1 -ErrorAction Stop | Out-Null
            Write-Log "BitLocker suspended for one reboot on $env:SystemDrive."
        }
    } catch {
        Write-Log "Could not suspend BitLocker: $($_.Exception.Message)"
    }
}

$failed = 0
foreach ($step in $plan) {
    try {
        if (Set-BiosAttribute -Name $step.Name -Value $step.Value) {
            Write-Log "  set $($step.Name) = $($step.Value) [$($step.Key)]"
        } else {
            $failed++
            Write-Log "  FAILED to set $($step.Name) = $($step.Value) [$($step.Key)]"
        }
    } catch {
        $failed++
        Write-Log "  FAILED to set $($step.Name) = $($step.Value) [$($step.Key)]: $($_.Exception.Message)"
    }
}

if ($LenovoNeedsSave) {
    try {
        if (Save-LenovoSettings) { Write-Log '  saved pending Lenovo settings' }
        else { $failed++; Write-Log '  FAILED to save pending Lenovo settings' }
    } catch {
        $failed++
        Write-Log "  FAILED to save pending Lenovo settings: $($_.Exception.Message)"
    }
}

if ($failed) {
    Write-Log "=== Finished with $failed failure(s) - check whether a BIOS password is set ==="
    exit 1
}

if ($requiredMissing) {
    Write-Log '=== Finished: prerequisites written, a required feature is still hidden - restart, the Intune retry picks it up ==='
    exit 1
}

Write-Log '=== Finished - restart required for the changes to take effect ==='
exit 0

