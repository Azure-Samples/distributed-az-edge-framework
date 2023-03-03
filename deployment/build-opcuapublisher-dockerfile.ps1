# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------

Param(
    [string] $Path = ".",
    [switch] $Debug
)

# Source definitions
$definitions = & (Join-Path $PSScriptRoot "../lib/Industrial-IoT/tools/scripts/docker-source.ps1") `
    -Path $Path -Debug:$Debug
if ($definitions.Count -eq 0) {
    Write-Host "Nothing to build."
    return
}

# Get currently active platform 
$dockerversion = &docker @("version") 2>&1 | %{ "$_" } `
    | ConvertFrom-Csv -Delimiter ':' -Header @("Key", "Value") `
    | Where-Object { $_.Key -eq "OS/Arch" } `
    | ForEach-Object { $platform = $_.Value }
if ($LastExitCode -ne 0) {
    throw "docker version failed with $($LastExitCode)."
}

if ([string]::IsNullOrEmpty($platform)) {
    $platform = "linux/amd64"
}

# Select build definition
$def = $definitions `
    | Where-Object { $_.platform -eq $platform } `
    | Select-Object

# Build docker image from definition

return $def