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
        $screenTitle = "-t '$WindowTitle'"
        $command = "gnome-terminal $screenTitle -- bash -c '$ProcessArgs; exec bash'"
        if($env:AZUREPS_HOST_ENVIRONMENT)
        {
            $command = "screen -d -m $screenTitle bash -c '$ProcessArgs; exec bash'"
        }
        Invoke-Expression $command
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

Function Stop-ProcessInNewTerminal {
    param (
        [string]$WindowTitle
    )

    if ($IsLinux) {
        # Linux-specific code
        $command = "pkill -f '$WindowTitle'"
        if($env:AZUREPS_HOST_ENVIRONMENT){
            $command = "pkill bash"
        }
        Invoke-Expression $command
        # sleep to ensure proxy is closed and then return
        Start-Sleep -Seconds 5
    }
    else {
        # Windows-specific code
        
        Get-Process | Where-Object { $_.MainWindowTitle -eq "$WindowTitle" } | ForEach-Object { $_.CloseMainWindow() }
        # sleep to ensure proxy is closed and then return
        Start-Sleep -Seconds 8
    }
}

Export-ModuleMember -Function Start-ProcessInNewTerminalPW
Export-ModuleMember -Function Stop-ProcessInNewTerminal