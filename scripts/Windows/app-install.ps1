[CmdLetBinding()]
Param(
  [String]$AwsCliUrl,
  [String]$ChromeUrl,
  [String]$DBeaverUrl,
  [String]$FirefoxUrl,
  [String]$FluxUrl,
  [String]$GitUrl,
  [String]$K9sUrl,
  [String]$KubectlUrl,
  [String]$NoSqlBoosterUrl,
  [String]$PythonUrl,
  [String]$RootCertUrl,
  [String]$UserCreationUrl
)

$__ScriptName = "developer-apps-installer.ps1"

# Location to save files.
$SaveDir = ${Env:Temp}

# Set a global bin-path "expander" variable
$global:ExtraPaths = ""


#################################
## BEGIN: "Plumbing" functions ##
##                             ##
function Cleanup-Download {
  Param(
    [string]$CleanupPath
  )

  # Check if cleanup-targe is a directory or a file
  if ( Test-Path -Path '${CleanupPath}' -PathType Container ) {
    Write-Verbose "Attempting to delete directory ${CleanupPath}..."
    Remove-Item -Path "${CleanupPath}" -Recurse
    $ret = $LASTEXITCODE
  } else {
    Write-Verbose "Attempting to delete file ${CleanupPath}..."
    Remove-Item -Path "${CleanupPath}"
    $ret = $LASTEXITCODE
  }

  # Return status from object-removal
  return $ret
}

function Download-File {
  Param( [string]$Url, [string]$SavePath )
  # Download a file, if it doesn't already exist.
  if( !(Test-Path ${SavePath} -PathType Leaf) ) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::SystemDefault
    $SecurityProtocolTypes = @([Net.SecurityProtocolType].GetEnumNames())
    if ("Tls11" -in $SecurityProtocolTypes) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls11
    }
    if ("Tls12" -in $SecurityProtocolTypes) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }

    (New-Object System.Net.WebClient).DownloadFile(${Url}, ${SavePath})
    Write-Verbose "Downloaded ${Url} to ${SavePath}"
  }
}

function Import-509Certificate {
  Param( [String]$CertFile, [String]$CertRootStore, [String]$CertStore )
  Write-Verbose "Importing certificate: ${CertFile} ..."
  $Pfx = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
  $Pfx.import($CertFile)
  $Store = New-Object System.Security.Cryptography.X509Certificates.x509Store(${CertStore},${CertRootStore})
  $Store.open("MaxAllowed")
  $Store.add($Pfx)
  $Store.close()
}

function Install-RootCertGroup {
  Param( [string]$RootCertHost )
  $CertDir = "${SaveDir}\certs-$(${RootCertHost}.Replace(`"http://`",`"`"))"
  Write-Verbose "Creating directory for certificates at ${CertDir}."
  New-Item -Path ${CertDir} -ItemType "directory" -Force -WarningAction SilentlyContinue | Out-Null

  Write-Verbose "... Checking for certificates hosted by: ${RootCertHost} ..."
  $CertUrls = @((Invoke-WebRequest -Uri ${RootCertHost}).Links | Where-Object { $_.href -Match ".*\.cer$" } | ForEach-Object { ${RootCertHost} + $_.href })

  Write-Verbose "... Found $(${CertUrls}.count) certificate(s) ..."
  Write-Verbose "... Downloading and importing certificate(s) ..."
  foreach( $UrlItem in ${CertUrls} ) {
    $CertFile = "${CertDir}\$((${UrlItem}.split('/'))[-1])"
    Download-File ${UrlItem} ${CertFile}
    if( ${CertFile} -match ".*root.*" ) {
      Import-509Certificate -CertFile ${CertFile} -CertRootStore "LocalMachine" -CertStore "Root"
      Write-Verbose "Imported trusted root CA certificate: ${CertFile}"
    } else {
      Import-509Certificate -CertFile ${CertFile} -CertRootStore "LocalMachine" -CertStore "CA"
      Write-Verbose "Imported intermediate CA certificate: ${CertFile}"
    }
  }
  Write-Verbose "... Completed import of certificate(s) from: ${RootCertHost}"
}

# MSI-installer helper function
function Install-Msi {
  Param(
    [String]$Installer,
    [String[]]$ExtraInstallerArgs
  )

  $Arguments = @()
  $Arguments += "/i"
  $Arguments += "`"${Installer}`""
  $Arguments += $ExtraInstallerArgs

  Write-Verbose "Installing $Installer"

  Start-Process "msiexec.exe" -ArgumentList ${Arguments} -NoNewWindow -PassThru -Wait
  $ret = $LASTEXITCODE

  # Try to ensure that the system-path actually gets updated for the MSI-instelled utility
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")

  return $ret
}

# EXE-installer helper function
function Install-Exe {
  Param( [String]$Installer, [String[]]$ExtraInstallerArgs )
  Write-Verbose "Installing $Installer"
  $ret = Start-Process "${Installer}" -ArgumentList ${ExtraInstallerArgs} -NoNewWindow -PassThru -Wait

  return $ret
}

# Expand system-wide PATH env
function Expand-SysPath {
  Param(
    [String]$ExtraPathDir
  )

  # Registry-hive key to update
  $RegKey = 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment'

  # Add executable to system path ("registry" method)
  $registryPath = (Get-Item $RegKey).GetValue('Path', $null, 'DoNotExpandEnvironmentNames')
  Set-ItemProperty -Path $RegKey -Name "Path" -Value "$registryPath;${ExtraPathDir}"


  # Add executable to system path (.Net method)
  [System.Environment]::SetEnvironmentVariable(
    "Path",
    $env:Path + ";${ExtraPathDir}",
    [System.EnvironmentVariableTarget]::Machine
  )

  # add EXE path to global "extra PATH" variable
  $global:ExtraPaths = "${global:ExtraPaths};${ExtraPathDir}"

}

function Fix-PS_CLI {
  Param(
    [string]$NuGetMinVersion,
    [string]$PSReadLineMinVersion
  )
  Install-PackageProvider -name NuGet -MinimumVersion "${NuGetMinVersion}" -Force

  # Update PowerShell ReadLine utility
  Install-Module `
   -Name PSReadLine `
   -Repository PSGallery `
   -MinimumVersion ${PSReadLineMinVersion} -Force

  Write-Verbose "The PSReadLine module has been updated"
}

function Reset-EnvironmentVarSet {
  foreach( $Level in "Machine", "User" ) {
    [Environment]::GetEnvironmentVariables(${Level}).GetEnumerator() | ForEach-Object {
      # For Path variables, append the new values, if they're not already in there.
      if($_.Name -match 'Path$') {
        $_.Value = ($((Get-Content "Env:$($_.Name)") + ";$($_.Value)") -split ';' | Select-Object -unique) -join ';'
      }
      $_
    } | Set-Content -Path { "Env:$($_.Name)" }
  }
}

function Create-User {
  Param(
    [Parameter(Mandatory=$false)] [String]$UserFullName,
    [Parameter(Mandatory=$false)] [String]$UserPasswd,
    [Parameter(Mandatory=$true)]  [String]$UserUidName,
    [switch]$UserIsAdmin
  )

  # Allow creation without a specifically-requested password-value
  if ( ! $UserPasswd ) {
    $UserPasswd = "4V3ryB@dP@ssw*rd"
  }

  # Create a "parameters" hasht-table
  $cmd_params = @{
    Name        = "${UserUidName}"
    Password    = ( ConvertTo-SecureString "${UserPasswd}" -AsPlainText -Force )
    FullName    = "${UserFullName}"
    Description = "Created by ${__ScriptName}"
  }

  # Create user from cmd_params hash-table
  New-LocalUser @cmd_params

  # Ensure user has RDP permissions
  Add-LocalGroupMember -Group "Remote Desktop Users" -Member "${UserUidName}"
  Write-Host "${UserUidName} added to 'Remote Desktop Users' local group"

  # Add as administrator if so requested
  if ( $UserIsAdmin ) {
    Add-LocalGroupMember -Group "Administrators" -Member "${UserUidName}"
    Write-Host "${UserUidName} added to Administrators local group"
  }
}
##                             ##
## END: "Plumbing" functions   ##
#################################

#######################################
## BEGIN: User-Application functions ##
##                                   ##
function Install-AWS_CLI {
  $AwsCliFile = "${SaveDir}\$(${AwsCliUrl}.split("/")[-1])"

  Download-File -Url ${AwsCliUrl} -SavePath ${AwsCliFile}

  $Arguments = @()
  $Arguments += "/passive"
  Install-Msi -Installer ${AwsCliFile} -ExtraInstallerArgs ${Arguments}

  Write-Verbose "Installed AWS CLI v2"

  # Cleanup downloaded file
  Cleanup-Download -CleanupPath "${AwsCliFile}"
}

function Install-Chrome {
  $ChromeFile = "${SaveDir}\$(${ChromeUrl}.split("/")[-1])"

  Write-Verbose "Downloading ${ChromeUrl} to ${ChromeFile}..."
  Download-File -Url ${ChromeUrl} -SavePath ${ChromeFile}

  $Arguments = @()
  $Arguments += "/SILENT"
  $Arguments += "/AllUsers"
  $Arguments += "/Install"

  Write-Verbose "Executing Chrome installer, ${ChromeFile}..."
  Install-Exe -Installer ${ChromeFile} -ExtraInstallerArgs ${Arguments}
  Write-Verbose "Installed Chrome"

  # Cleanup downloaded file
  Cleanup-Download -CleanupPath "${ChromeFile}"
}

function Install-DBeaver {
  $DBeaverFile = "${SaveDir}\$(${DBeaverUrl}.split("/")[-1])"

  Write-Verbose "Downloading ${DBeaverUrl} to ${DBeaverFile}..."
  Download-File -Url ${DBeaverUrl} -SavePath ${DBeaverFile}

  $Arguments = @()
  $Arguments += "/S"
  $Arguments += "/allusers"

  Write-Verbose "Executing DBeaver installer, ${DBeaverFile}..."
  Install-Exe -Installer ${DBeaverFile} -ExtraInstallerArgs ${Arguments}
  Write-Verbose "Installed DBeaver"

  # Cleanup downloaded file
  Cleanup-Download -CleanupPath "${DBeaverFile}"
}

function Install-Firefox {
  $FirefoxFile = "${SaveDir}\firefox-installer.exe"

  Download-File -Url ${FirefoxUrl} -SavePath ${FirefoxFile}

  $Arguments = @()
  $Arguments += "/SILENT"
  Install-Exe -Installer ${FirefoxFile} -ExtraInstallerArgs ${Arguments}

  Write-Verbose "Installed Firefox"

  # Cleanup downloaded file
  Cleanup-Download -CleanupPath "${FirefoxFile}"
}

function Install-Flux {
  ${FluxFile} = "${SaveDir}\$(${FluxUrl}.split("/")[-1])"
  ${FluxInstallDir} = "C:\Program Files\Flux"

  # Try to make a bit more idempotent
  if ( -not ( Test-Path ${FluxInstallDir} ) ) {
    # Download Flux archive file
    Download-File -Url ${FluxUrl} -SavePath ${FluxFile}

    # unarchive Flux archive file
    Expand-Archive -Path ${FluxFile} -DestinationPath ${FluxInstallDir}

    # Add Flux executable to system path
    Expand-SysPath -ExtraPathDir ${FluxInstallDir}

    # Cleanup downloaded file
    Cleanup-Download -CleanupPath "${FluxFile}"
  }
}

function Install-Git {
  $GitFile = "${SaveDir}\$(${GitUrl}.split("/")[-1])"

  Download-File -Url ${GitUrl} -SavePath ${GitFile}

  $Arguments = @()
  $Arguments += "/VERYSILENT"
  $Arguments += "/NOCANCEL"
  $Arguments += "/NORESTART"
  $Arguments += "/SAVEINF=${SaveDir}\git_params.txt"
  Install-Exe -Installer ${GitFile} -ExtraInstallerArgs ${Arguments}

  Write-Verbose "Installed Git"

  # Cleanup downloaded file
  Cleanup-Download -CleanupPath "${GitFile}"
}

function Install-K9Util {
  $K9sFile = "${SaveDir}\$(${K9sUrl}.split("/")[-1])"
  ${K9sInstallDir} = "C:\Program Files\k9s"

  # Try to make a bit more idempotent
  if ( -not ( Test-Path ${K9sInstallDir} ) ) {
    # Download K9s archive file
    Download-File -Url ${K9sUrl} -SavePath ${K9sFile}

    # unarchive K9s archive file
    Expand-Archive -Path ${K9sFile} -DestinationPath ${K9sInstallDir}

    # Add K9s executable to system path
    Expand-SysPath -ExtraPathDir ${K9sInstallDir}

    # Cleanup downloaded file
    Cleanup-Download -CleanupPath "${K9sFile}"
  }
}

function Install-Kubectl {
  ${K8sInstallDir} = "C:\Program Files\Kubernetes"

  # Create K8s install-directory as necessary
  if ( -not ( Test-Path ${K8sInstallDir} ) ) {
    # Create installation-directory
    New-Item -Path ${K8sInstallDir} -ItemType Directory
  }

  # Download K8s binary
  if ( -not ( Test-Path "${K8sInstallDir}\kubectl.exe" ) ) {
    # Download Kubectl archive file
    Download-File -Url ${KubectlUrl} -SavePath "${K8sInstallDir}\kubectl.exe"

    # Add Kubernetes executable to system path
    Expand-SysPath -ExtraPathDir ${K8sInstallDir}
  }
}

function Install-NoSqlBooster {
  $NoSqlBoosterFile = "${SaveDir}\$(${NoSqlBoosterUrl}.split("/")[-1])"

  Download-File -Url ${NoSqlBoosterUrl} -SavePath ${NoSqlBoosterFile}

  $Arguments = @()
  $Arguments += "/S"
  $Arguments += '/D="C:\Program Files\NoSQLBooster"'

  Install-Exe -Installer ${NoSqlBoosterFile} -ExtraInstallerArgs ${Arguments}

  Write-Verbose "Installed NoSqlBooster"

  # Cleanup downloaded file
  Cleanup-Download -CleanupPath "${NoSqlBoosterFile}"
}

function Install-Python {
  $PythonFile = "${SaveDir}\$(${PythonUrl}.split("/")[-1])"

  Download-File -Url ${PythonUrl} -SavePath ${PythonFile}

  if ($PythonFile -match "^.*msi$") {
    $Arguments = @()
    $Arguments += "/qn"
    $Arguments += "ALLUSERS=1"
    $Arguments += "ADDLOCAL=ALL"
    Install-Msi -Installer ${PythonFile} -ExtraInstallerArgs ${Arguments}
  }
  elseif ($PythonFile -match "^.*exe$") {
    $Arguments = @()
    $Arguments += "/quiet"
    $Arguments += "InstallAllUsers=1"
    $Arguments += "PrependPath=1"
    Install-Exe -Installer ${PythonFile} -ExtraInstallerArgs ${Arguments}
  }

  Write-Verbose "Installed Python"

  # Cleanup downloaded file
  Cleanup-Download -CleanupPath "${PythonFile}"
}

function Parse-JsonFile {
  # Where to write downloaded user-creation spec-file to
  $UserCreationFile = "${SaveDir}\$(${UserCreationUrl}.split("/")[-1])"

  # Download user-creation spec-file
  Download-File -Url ${UserCreationUrl} -SavePath ${UserCreationFile}

  # Abort if given file-path is not valid
  if ( -not ( Test-Path $UserCreationFile ) ) {
      Write-Error "File not found: $UserCreationFile"
      return
  }

  # Load JSON-payload from file and convert to PS object
  $JsonStream = Get-Content -Raw -Path "${UserCreationFile}" | ConvertFrom-Json

  # The structure has a 'Users' array containing a single object with dynamic keys
  foreach ($userContainer in $JsonStream.Users) {
    # Iterate through each dynamic key (the usernames)
    foreach ($username in $userContainer.psobject.Properties.Name) {
      # Get the array associated with that username
      $userDetails = $userContainer.$username

      foreach ($detail in $userDetails) {
	# Send extracted attributes to user-creation function
	Create-User -UserUidName "$username" `
	  -UserFullName "${detail}.givenName ${detail}.surname" `
	  -UserPasswd "${detail}.initialPassword"
      }
    }
  }

}
##                                   ##
## END: User-Application functions   ##
#######################################

# Main

# Ensure Powershell's PSReadLine module is updated
Fix-PS_CLI -NuGetMinVersion '2.8.5.201' -PSReadLineMinVersion '2.2.2'

if( ${RootCertUrl} ) {
  # Download and install the root certificates.
  Write-Verbose "Root certificates host url is ${RootCertUrl}"
  Install-RootCertGroup ${RootCertUrl}
}

# Conditionally download and install AWS CLI v2
if( ${AwsCliUrl} ) {
  Write-Verbose "AWS CLI v2 will be installed from {$AwsCliUrl}"
  Install-AWS_CLI
}

# Conditionally Install Python
if( ${PythonUrl} ) {
  Write-Verbose "Python will be installed from ${PythonUrl}"
  Install-Python
}

# Conditionally download and install Chrome
if( ${ChromeUrl} ) {
  Write-Verbose "Chrome will be installed from {$ChromeUrl}"
  Install-Chrome
}

# Conditionally download and install DBeaver
if( ${DBeaverUrl} ){
  Write-Verbose "DBeaver will be installed from ${DBeaverUrl}"
  Install-DBeaver
}

# Conditionally download and install Firefox
if( ${FirefoxUrl} ){
  Write-Verbose "Firefox will be installed from ${FirefoxUrl}"
  Install-Firefox
}

# Conditonally download and install flux
if( ${FluxUrl} ) {
  Write-Verbose "Flux will be installed from ${FluxUrl}"
  Install-Flux
}

# Conditonally download and install git
if( ${GitUrl} ) {
  Write-Verbose "Git will be installed from ${GitUrl}"
  Install-Git
}

# Conditionally download and install K9s utility
if( ${K9sUrl} ) {
  Write-Verbose "K9s will be installed from ${K9sUrl}"
  Install-K9Util
}

# Conditionally download and install Kubectl utility
if( ${KubectlUrl} ) {
  Write-Verbose "Kubectl will be installed from ${KubectlUrl}"
  Install-Kubectl
}

# Conditionally download and install NoSqlBooster
if( ${NoSqlBoosterUrl} ) {
  Write-Verbose "NoSqlBooster will be installed from {$NoSqlBoosterUrl}"
  Install-NoSqlBooster
}
if( $UserCreationUrl ) {
  Write-Verbose "User-creation will be based on data from ${UserCreationUrl}"
  Parse-JsonFile
}


# Try to append naked EXE paths to system-path
# Add executable to system path (.Net method)
[System.Environment]::SetEnvironmentVariable(
  "Path",
  $env:Path + ";${global:ExtraPaths}",
  [System.EnvironmentVariableTarget]::Machine
)


Write-Verbose "${__ScriptName} complete!"
