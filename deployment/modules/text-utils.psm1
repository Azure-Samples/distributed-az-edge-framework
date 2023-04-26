Function Write-Title ([string]$text) {
    $width = (Get-Host).UI.RawUI.WindowSize.Width
    $title = ""
    if($text.length -ne 0)
    {
        $title = "=[ " + $text + " ]="
    }

    Write-Host $title.PadRight($width, "=") -ForegroundColor green
}

Function Get-DecodedToken([string]$path)
{
    $tokenB64 = Get-Content -Path $path
    $decodedToken = ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(($tokenB64))))
    
    return $decodedToken
}

Export-ModuleMember -Function Write-Title
Export-ModuleMember -Function Get-DecodedToken