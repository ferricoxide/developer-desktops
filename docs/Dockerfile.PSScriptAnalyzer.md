# PowerShell Script Analyzer Docker Container

The `Dockerfile.PSScriptAnalyzer` file is used to build a docker container hosting the [PSScriptAnalyzer](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/overview) PowerShell Module. This dockerfile allows you to arbitrarily select which version of the PSScriptAnalyzer PowerShell module should be installed into the resulting docker container.

As of this document's writing, the current version of the PSScriptAnalyzer PowerShell module is version 1.24.0. However, this version has a bug that prevents its use as a linting-utility. It is recommended to use one of the 1.22 or 1.23 versions of the module. To do so, invoke your docker container build operation with the arguments:

* MAX_ANALYZE_VERSION
* MIN_ANALYZE_VERSION

To set upper and lower bounds on theversion of the PSScriptAnalyzer PowerShell module installed.

While (as of this writing) the current module's versions' "X.Y.Z" version-nomenclature only ever has a value of `0` for the `Z` position, it is still recommended to use a minimum `Z`-value of `0` and a maximum `Z`-value of `999`. Setting a range, like this, will allow for the possibility of bugfix releases changing the `Z`-value to a higher number.

# Building with podman
If using [podman](https://podman.io/) to build images, an execution similar to:

```
podman build \
  --format docker \
  --build-arg MAX_ANALYZE_VERSION=1.22.999 \
  --build-arg MIN_ANALYZE_VERSION=1.22.0 \
  -t ps_lint:1.22.0 \
  -f ci/local/Dockerfile.PSScriptAnalyzer
```

Will produce a docker-formatted container.

Note: This Dockerfile uses the `SHELL` command to facilitate the use of the PowerShell source-image's PowerShell `Set-PSRepository` and `Install-Module` commands. Podman defualts to OCI-formatted containers. The `SHELL` verb is not compatible with creation of OCI-formatted containers. Therefore, it is necessary to override this default by passing the `--format docker` argument. 

The version of the installed PSScriptAnalyzer PowerShell module may be verified by executing:

```
podman run ps_lint:1.22.0 pwsh -Command "( Get-InstalledModule PSScriptAnalyzer ).Version"
```

Output should be similar to the following

```
1.22.0
```


