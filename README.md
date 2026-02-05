# developer-desktops

This project is intended to act as a repository of tooling for building "developer" desktops for developers and other users that require a consistent set of tooling be pre-installed to Windows- or Linux-based environments:

* Windows automation will be delivered in the form of Powershell scripts
* Linux automation will be delivered in the form of BASH scripts

Further, this project will contain Dockerfiles suitable to help in the linting of the above automation-types

For examples on how to use this project's automation examine the files in the [docs/examples/userData](docs/examples/userData) directory. Files in this directory may be used "as is" or as "inspiration". If used "as is":

* Copy-n-paste their content into the launcher-GUI's userData input-box
* Download the desired file(s) to the launcher-CLI's host and used a `file://`-based userData reference to the (local) download-path
