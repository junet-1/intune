<#
.SYNOPSIS
    Creates a code signing certificate (Root CA + leaf) and signs PowerShell
    scripts - the native Windows counterpart to the OpenSSL/osslsigncode workflow.

.DESCRIPTION
    Two modes:

    -NewCert : Creates a self-signed Root CA and a leaf code signing certificate
               chained to it (New-SelfSignedCertificate). Exports the Root public
               certificate (.cer) for Intune trusted-certificate deployment, the
               leaf public certificate (.cer) for the Trusted Publishers store, and
               the leaf as a password-protected .pfx backup.

    -Sign    : Signs one or more scripts with Set-AuthenticodeSignature, including a
               timestamp so signatures stay valid after the certificate expires.
               The certificate is taken from a .pfx file or from the certificate
               store (by thumbprint).

.EXAMPLE
    .\New-CodeSigning.ps1 -NewCert -OutputDir .\certs

.EXAMPLE
    .\New-CodeSigning.ps1 -Sign -PfxPath .\certs\codesign.pfx `
        -Path ..\Reset-LocalAdmins\Detect-LocalAdmins.ps1, ..\Reset-LocalAdmins\Remediate-LocalAdmins.ps1

.EXAMPLE
    .\New-CodeSigning.ps1 -Sign -Thumbprint A1B2C3... -Path .\MyScript.ps1

.NOTES
    Requires Windows PowerShell 5.1+ or PowerShell 7+ (New-SelfSignedCertificate is
    Windows-only). Run certificate creation on a trusted admin workstation.
#>

[CmdletBinding(DefaultParameterSetName = 'Sign')]
param(
    # ---- NewCert mode ----
    [Parameter(Mandatory, ParameterSetName = 'NewCert')]
    [switch]$NewCert,

    [Parameter(ParameterSetName = 'NewCert')]
    [string]$OutputDir = '.\certs',

    [Parameter(ParameterSetName = 'NewCert')]
    [string]$Organization = 'Contoso',

    [Parameter(ParameterSetName = 'NewCert')]
    [string]$RootCommonName = 'Contoso Code Signing Root CA',

    [Parameter(ParameterSetName = 'NewCert')]
    [string]$LeafCommonName = 'Contoso Script Signing',

    [Parameter(ParameterSetName = 'NewCert')]
    [int]$RootYears = 10,

    [Parameter(ParameterSetName = 'NewCert')]
    [int]$LeafYears = 3,

    # ---- Sign mode ----
    [Parameter(Mandatory, ParameterSetName = 'Sign')]
    [switch]$Sign,

    [Parameter(ParameterSetName = 'Sign')]
    [string]$PfxPath,

    [Parameter(ParameterSetName = 'Sign')]
    [string]$Thumbprint,

    [Parameter(Mandatory, ParameterSetName = 'Sign')]
    [string[]]$Path,

    # ---- shared ----
    [string]$TimestampUrl = 'http://timestamp.digicert.com'
)

$ErrorActionPreference = 'Stop'

function New-CodeSigningChain {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    $OutputDir = (Resolve-Path -LiteralPath $OutputDir).Path

    Write-Host '>> Creating Root CA...' -ForegroundColor Cyan
    $root = New-SelfSignedCertificate `
        -Subject "CN=$RootCommonName, O=$Organization, C=DE" `
        -KeyUsage CertSign, CRLSign, DigitalSignature `
        -KeyLength 4096 -HashAlgorithm SHA256 `
        -KeyExportPolicy Exportable `
        -CertStoreLocation 'Cert:\CurrentUser\My' `
        -NotAfter (Get-Date).AddYears($RootYears) `
        -TextExtension @('2.5.29.19={critical}{text}CA=true&pathlength=0')

    Write-Host '>> Creating leaf code signing certificate...' -ForegroundColor Cyan
    $leaf = New-SelfSignedCertificate `
        -Subject "CN=$LeafCommonName, O=$Organization, C=DE" `
        -Type CodeSigningCert `
        -KeyLength 4096 -HashAlgorithm SHA256 `
        -KeyExportPolicy Exportable `
        -CertStoreLocation 'Cert:\CurrentUser\My' `
        -NotAfter (Get-Date).AddYears($LeafYears) `
        -Signer $root

    $rootCer = Join-Path $OutputDir 'codesign-root.cer'
    $leafCer = Join-Path $OutputDir 'codesign.cer'
    $leafPfx = Join-Path $OutputDir 'codesign.pfx'

    Export-Certificate -Cert $root -FilePath $rootCer -Type CERT | Out-Null
    Export-Certificate -Cert $leaf -FilePath $leafCer -Type CERT | Out-Null

    $pfxPw = Read-Host 'Password to protect the leaf .pfx backup' -AsSecureString
    Export-PfxCertificate -Cert $leaf -FilePath $leafPfx -Password $pfxPw -ChainOption BuildChain | Out-Null

    # Root private key does not belong on the signing machine long-term - remove it
    # from the store; the exported .cer (public only) is all the devices need.
    Remove-Item -LiteralPath "Cert:\CurrentUser\My\$($root.Thumbprint)" -Force

    Write-Host ''
    Write-Host 'Created:' -ForegroundColor Green
    Write-Host "  Root  (deploy to Trusted Root):       $rootCer"
    Write-Host "  Leaf  (deploy to Trusted Publishers): $leafCer"
    Write-Host "  Leaf  (.pfx backup, keep secret):     $leafPfx"
    Write-Host "  Leaf thumbprint (store):              $($leaf.Thumbprint)"
    Write-Host ''
    Write-Host 'Sign with:  .\New-CodeSigning.ps1 -Sign -Thumbprint ' -NoNewline
    Write-Host "$($leaf.Thumbprint) -Path .\script.ps1"
}

function Get-SigningCertificate {
    if ($PfxPath) {
        $PfxPath = (Resolve-Path -LiteralPath $PfxPath).Path
        $pfxPw = Read-Host 'PFX password' -AsSecureString
        return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($PfxPath, $pfxPw)
    }
    if ($Thumbprint) {
        $cert = Get-ChildItem -Path 'Cert:\CurrentUser\My', 'Cert:\LocalMachine\My' -ErrorAction SilentlyContinue |
            Where-Object { $_.Thumbprint -eq ($Thumbprint -replace '\s', '') } |
            Select-Object -First 1
        if (-not $cert) { throw "No certificate with thumbprint $Thumbprint found in the store." }
        return $cert
    }
    # Fall back to the only code signing cert available, if unambiguous.
    $candidates = @(Get-ChildItem -Path 'Cert:\CurrentUser\My' |
        Where-Object { $_.EnhancedKeyUsageList.ObjectId -contains '1.3.6.1.5.5.7.3.3' -and $_.HasPrivateKey })
    if ($candidates.Count -eq 1) { return $candidates[0] }
    throw 'Specify -PfxPath or -Thumbprint (no single code signing certificate found in the store).'
}

function Invoke-ScriptSigning {
    $cert = Get-SigningCertificate
    if (-not $cert.HasPrivateKey) { throw 'The selected certificate has no usable private key.' }
    Write-Host ">> Signing with: $($cert.Subject)  [$($cert.Thumbprint)]" -ForegroundColor Cyan

    foreach ($p in $Path) {
        $resolved = Resolve-Path -LiteralPath $p
        foreach ($file in $resolved) {
            $res = Set-AuthenticodeSignature `
                -FilePath $file.Path `
                -Certificate $cert `
                -HashAlgorithm SHA256 `
                -IncludeChain All `
                -TimestampServer $TimestampUrl

            $color = if ($res.Status -eq 'Valid') { 'Green' } else { 'Yellow' }
            Write-Host ("  {0,-8} {1}" -f $res.Status, $file.Path) -ForegroundColor $color
            if ($res.Status -ne 'Valid') {
                Write-Host "           $($res.StatusMessage)" -ForegroundColor Yellow
            }
        }
    }
}

switch ($PSCmdlet.ParameterSetName) {
    'NewCert' { New-CodeSigningChain }
    'Sign'    { Invoke-ScriptSigning }
}
