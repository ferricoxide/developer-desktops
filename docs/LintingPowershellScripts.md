This project includes a Dockerfile for creating a docker container with the PSScriptAnalyzer utility within it. See the [docs/Dockerfile.PSScriptAnalyzer.md](./Dockerfile.PSScriptAnalyzer.md) document for instructions on building the container. Once the container is built and in a registry &mdash; even just a local registry &mdash; it can be used to do basic linting of PowerShell-based automation.

# Podman-Based Execution

If using Podman to run containers, execution will look something like:

```
podman run \
  -v .../developer-desktops:/mnt/developer-desktops \
  <CONTAINER_ID> \
  pwsh -Command 'Invoke-ScriptAnalyzer `
    -Settings /mnt/developer-desktops/.psscriptanalyzer-settings.psd1 `
    -EnableExit `
    -Path /mnt/developer-desktops/scripts/Windows/app-install.ps1'
```

The value of `<CONTAINER_ID>` may be either the `<REPOSITORY>:<TAG>` value (e.g., `localhost/ps_lint:1.23.0`) or the `IMAGE ID` value (e.g., `b3b8c97ef29d`). See the following `podman images` output for guidance:

```
$ podman images
REPOSITORY                    TAG                      IMAGE ID      CREATED         SIZE
localhost/ps_lint             1.22.0                   ac8689eaf826  4 seconds ago   646 MB
localhost/ps_lint             1.23.0                   b3b8c97ef29d  50 seconds ago  646 MB
...
```

# Output

## Issues Found

If there are findings, output will typically look something like:

```
RuleName                            Severity     ScriptName Line  Message
--------                            --------     ---------- ----  -------
PSUseApprovedVerbs                  Warning      app-instal 35    The cmdlet 'D
                                                 l.ps1            ownload-File'
                                                                   uses an
                                                                  unapproved
                                                                  verb.
PSUseApprovedVerbs                  Warning      app-instal 132   The cmdlet
                                                 l.ps1            'Fix-PS_CLI'
                                                                  uses an
                                                                  unapproved
                                                                  verb.
PSUseShouldProcessForStateChangingF Warning      app-instal 148   Function 'Res
unctions                                         l.ps1            et-Environmen
                                                                  tVarSet' has
                                                                  verb that
                                                                  could change
                                                                  system
                                                                  state.
                                                                  Therefore,
                                                                  the function
                                                                  has to
                                                                  support 'Shou
                                                                  ldProcess'.
```

And the container will return a non-zero exit-code. The output's column names should be self-explanatory.

## No Issues Found

If there are no findings, no text output will be produced and the container will return a zero exit-code.

# Remediation

For findings that you wish to address, do a web search for the relevant string in the `Message` column. Make the necessary changes and re-run the linter. Iterate until there are no findings noted (and the container returns a zero exit-code)

For findings you wish to ignore, update the `developer-desktops/.psscriptanalyzer-settings.psd1`. A basic configuration (i.e., one with no rule-exclusions) will look something like:

```powershell
@{
  # Severity levels to include
  Severity = @('Error', 'Warning')

  # Rules to exclude
  ExcludeRules = @(
  )
}
```

To suppress the findings in the prior example container-output, update the above configuration-snippet to look like:

```powershell
@{
  # Severity levels to include
  Severity = @('Error', 'Warning')

  # Rules to exclude
  ExcludeRules = @(
    'PSUseApprovedVerbs',
    'PSUseShouldProcessForStateChangingFunctions'
  )
}
```

The values in the `ExcludeRules` list are taken directly from the container output's `RuleName` column.
