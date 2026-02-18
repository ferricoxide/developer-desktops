# Introduction

The [`app_install.ps1`](../scripts/Windows/app-install.ps1) file is a Powershell script designed to facilitate the installation of a set of common, developer-oriented tools. As of this writing, this script can automate the installation of the:

* The AWS managment utility (CLI)
* The Chrome web browser
* The dBeaver database managment GUI
* The Firefox web broswer
* The Flux CI/CD took for Kubernetes
* The Git source control management utility
* The K9S Kubernetes management utility (TUI)
* The Kubectl Kubernetes management utility (CLI)
* The NoSQLBoster IDE for MongoDB
* The Python language
* Optional/Additional root certificate authories

None of the above components are installed without the script-user requesting their installation. Installation-request is done by passing a parameter-flag and an associated value.

Additionally, the automation will set up an arbitrary set of locally-managed, RDP-enabled users. User-setup is requested by passing a further parameter-flag that points to a JSON-formatted user-specification file.

If the capability to install further tooling is desired, pleas open an issue.

## Parameters

The Windows (PowerShell) script, `app-install.ps1` currently accepts the following arguments:

* `AwsCliUrl`: Download location for the AWS CLI v2 (MSI-based) installer.
* `ChromeUrl`: Download location for the Chrome browser's (EXE-based) installer
* `DBeaverUrl`: Download location for the dBeaver database management GUI's (EXE-based) installer
* `FirefoxUrl`: Download location for the Firefox browser's (EXE-based) installer
* `FluxUrl`: Download location for the Flux utility. Downloaded file is a ZIP-encapsulated, bare executable
* `GitUrl`: Download location for the Git utility-suite's (EXE-based) installer
* `K9sUrl`: Download location for the K9s utility. Downloaded file is a ZIP-encapsulated, bare executable
* `KubectlUrl`: Download location for the `kubectl` utility. Downloaded file is a bare executable
* `NoSqlBoosterUrl`: Download location for the NoSQLBooster GUI utility's (EXE-based) installer
* `PythonUrl`: Download location for the Python interpreter-suite. May be delivered as either an EXE- or MSI-based installer
* `RootCertUrl: Download location for a bundle of private root-certifications.
* `UserCreationUrl`: The URI of a user-specification file.

## Values

For hosts that are able to download from public, Internet-hosted repositories, suitable link-values will (as of the writing of this document) be:

* `AwsCliUrl`: [https://awscli.amazonaws.com/AWSCLIV2.msi](https://awscli.amazonaws.com/AWSCLIV2.msi)
* `ChromeUrl`: [https://dl.google.com/chrome/install/latest/chrome_installer.exe](https://dl.google.com/chrome/install/latest/chrome_installer.exe)
* `DBeaverUrl`: [https://dbeaver.io/files/dbeaver-ce-latest-x86_64-setup.exe](https://dbeaver.io/files/dbeaver-ce-latest-x86_64-setup.exe)
* `FirefoxUrl`: [https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US](https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US)
* `FluxUrl`: [https://github.com/fluxcd/flux2/releases/download/v2.7.5/flux_2.7.5_windows_amd64.zip](https://github.com/fluxcd/flux2/releases/download/v2.7.5/flux_2.7.5_windows_amd64.zip)
* `GitUrl`: [https://github.com/git-for-windows/git/releases/download/v2.52.0.windows.1/Git-2.52.0-64-bit.exe](https://github.com/git-for-windows/git/releases/download/v2.52.0.windows.1/Git-2.52.0-64-bit.exe)
* `K9sUrl`: [https://github.com/derailed/k9s/releases/download/v0.50.18/k9s_Windows_amd64.zip](https://github.com/derailed/k9s/releases/download/v0.50.18/k9s_Windows_amd64.zip)
* `KubectlUrl`: [https://dl.k8s.io/v1.35.0/bin/windows/amd64/kubectl.exe](https://dl.k8s.io/v1.35.0/bin/windows/amd64/kubectl.exe)
* `NoSqlBoosterUrl`: [https://s3.nosqlbooster.com/download/releasesv10/nosqlbooster4mongo-10.1.1.exe](https://s3.nosqlbooster.com/download/releasesv10/nosqlbooster4mongo-10.1.1.exe)
* `PythonUrl`: [https://www.python.org/ftp/python/3.14.2/python-3.14.2-amd64.exe](https://www.python.org/ftp/python/3.14.2/python-3.14.2-amd64.exe)
* `UserCreationUrl`: Currently supports `http://`, `https://` or `file://` URIs.

## User Creation

As noted above, an arbitrary number of users may be created through this automation. The users' creation is specified through a JSON-formatted user-specification file (see: the [example](examples/support_files/RSA_Users.json) file). The basic format of the specification-file is:

```json
{
  "Users": [
    {
      "<USER_ID>": [
        {
          "givenName": "<USER_FIRST_NAME>",
          "initialPassword": "<CLEARTEXT_PASSWORD_STRING>",
          "localAdmin": "true",
          "surname": "<USER_LAST_NAME>"
        }
      ]
    }
  ]
}
```

The `<USER_ID>` object-key and the `givenName` and `surname` object-attributes are mandatory. The `initialPassword` and `localDamin` object-attributes are optional:

* `<USER_ID>`: A string of (typically) between 8 and 20 alphanumeric characters
* `givenName`: A string of ASCII characters matching the account-user's first name
* `surName`: A string of ASCII characters matching the account-user's last name
* `initialPassword`: A string of alphanumeric, ASCII characters of at least 8 character's length (14+ recommended). This string will be encrypted by the script when the user-account is created. If a value is not specified a default value will be set
* `localAdmin`: A simple boolean. If the attribute is specified with a value of `true`, the user-account will be created as a local administrator. If the attribute is left unset or set to any value other than `true`, the user-account will be created only as an RDP-enabled user.

The value of the specified `givenName` and `surName` values will be combined to create the user-account's full-name value.


## Cautions

* Failing to specify a value will result in the associated application **_not_** being installed.
* Specifying a non-valid value will typically result in the automation aborting.
* If running the script so as to create additional RDP users, it is recommended to place the user-specification in a protected location (password-protected HTTP/S URL, an S3-hosted file, etc.). This recommendation is due to the use of cleartext strings for the specification-file's user-password field(s)
