# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------

# Function to start a process in a new minimized window

Function Start-ProcessInNewTerminalPW {
    param (
        [string]$ProcessArgs,
        [string]$WindowTitle
    )

    if ($IsLinux) {
        # Linux-specific code
        if($env:AZUREPS_HOST_ENVIRONMENT)
        {
            $screenTitle = "-t '$WindowTitle'"
            $command = "screen -d -m $screenTitle bash -c '$ProcessArgs; exec bash'"
            Invoke-Expression $command
        }
        else {
            Write-Error "This script is not tested on Linux/Unix other than Azure Cloud Shell. Please run this script in Azure Cloud Shell."
        }
    }
    else {
        # Windows-specific code
        $process = Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoExit", "-Command", "$ProcessArgs" -WindowStyle Minimized -PassThru
        
        if (-not ([System.Management.Automation.PSTypeName]'WindowTitle').Type) {
            Add-Type -TypeDefinition @"
                using System;
                using System.Runtime.InteropServices;
                public class WindowTitle {
                    [DllImport("user32.dll")]
                    public static extern bool SetWindowText(IntPtr hWnd, string lpString);
                }
"@
        }

        # add delay to set title
        Start-Sleep -Seconds 5
        [WindowTitle]::SetWindowText($process.MainWindowHandle, $WindowTitle)

    }

}

# Function to close a process in a new minimized window
Function Stop-ProcessInNewTerminal {
    param (
        [string]$WindowTitle
    )

    if ($IsLinux) {
        # Linux-specific code
        if($env:AZUREPS_HOST_ENVIRONMENT){
            $command = "pkill bash"
            Invoke-Expression $command

            # check if process is still running
            while (Get-Process -Name "bash" -ErrorAction SilentlyContinue) {
                Write-Host "Waiting for bash process to close"
                Start-Sleep -Seconds 5
            }
        }
        else
        {
            Write-Warning "When enabling Arc please note the scripts are not tested on Linux/Unix other than Azure Cloud Shell"
        }
    }
    else {
        # Windows-specific code
        
        Get-Process | Where-Object { $_.MainWindowTitle -eq "$WindowTitle" } | ForEach-Object { $_.CloseMainWindow() }
        # sleep to ensure proxy is closed and then return

        while(Get-Process | Where-Object { $_.MainWindowTitle -eq "$WindowTitle" }){
            Write-Host "Waiting for $WindowTitle process to close"
            Start-Sleep -Seconds 3
        }
    }
}

# Function to check if the environment is supported for running background process terminal
Function Confirm-AzEnvironment {
    
    if($IsLinux -and ($env:AZUREPS_HOST_ENVIRONMENT -eq $False))
    {
        Write-Warning "When enabling Arc please note the scripts are not tested on Linux/Unix other than Azure Cloud Shell"
        return $True
    }
    Write-Host "returning true"
    return $True
}

Function TestMay{
    Write-Host "TestMay"
}

Export-ModuleMember -Function Start-ProcessInNewTerminalPW
Export-ModuleMember -Function Stop-ProcessInNewTerminal
Export-ModuleMember -Function Confirm-AzEnvironment 
Export-ModuleMember -Function TestMay
