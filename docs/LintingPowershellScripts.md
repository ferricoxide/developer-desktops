This project includes a Dockerfile for creating a docker container with the PSScriptAnalyzer utility within it. See the [docs/Dockerfile.PSScriptAnalyzer.md](./Dockerfile.PSScriptAnalyzer.md) document for instructions on building the container.

podman run -v /home/ferric/GIT/P3/GitHub.Com/developer-desktops:/mnt/developer-desktops ps-linter:ps_script_analyzer-1.23 pwsh -Command pwsh -Command "Invoke-ScriptAnalyzer -EnableExit -Path /mnt/developer-desktops/scripts/Windows/app-install.ps1 -Settings /mnt/developer-desktops/.psscriptanalyzer-settings.psd1"

