<powershell>
$BootstrapUrl = "https://watchmaker.cloudarmor.io/releases/latest/watchmaker-bootstrap.ps1"
$AppInstallUrl = "https://raw.githubusercontent.com/ferricoxide/developer-desktops/refs/heads/Feature/AddUserCreation/scripts/Windows/app-install.ps1"
$UserCreationUrl = "https://raw.githubusercontent.com/ferricoxide/developer-desktops/refs/heads/Feature/AddUserCreation/docs/examples/support_files/RSA_Users.json"
$PythonUrl = "https://www.python.org/ftp/python/3.14.2/python-3.14.2-amd64.exe"
$PypiUrl = "https://pypi.org/simple"

# Use TLS 1.2+
[Net.ServicePointManager]::SecurityProtocol = "Tls12, Tls13"

# Download bootstrap file
$BootstrapFile = "${Env:Temp}\$(${BootstrapUrl}.split('/')[-1])"
(New-Object System.Net.WebClient).DownloadFile("$BootstrapUrl", "$BootstrapFile")

# Download app-installer file
$AppInstallFile = "${Env:Temp}\$(${AppInstallUrl}.split('/')[-1])"
(New-Object System.Net.WebClient).DownloadFile("$AppInstallUrl", "$AppInstallFile")

# Download user-creation spec-file
$UserCreationFile = "${Env:Temp}\$(${UserCreationUrl}.split('/')[-1])"
(New-Object System.Net.WebClient).DownloadFile("$UserCreationUrl", "$UserCreationFile")

# Install python
& "$BootstrapFile" -PythonUrl "$PythonUrl" -Verbose -ErrorAction Stop

## # Use app-installer file to install python
## & "$AppInstallFile" `
##     -UserCreationUrl "file://./RSA_Users.json"

# Install Watchmaker
python -m pip install --index-url="$PypiUrl" --upgrade pip setuptools
python -m pip install --index-url="$PypiUrl" --upgrade watchmaker
</powershell>
