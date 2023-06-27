
Function Get-AzShortRegion ([string]$locationShortorLong) {
    $regionShort = ""
    $regionName = (az account list-locations --query "[? contains(displayName, '$locationShortorLong') || contains(name, '$locationShortorLong')].name" -o json) `
        | ConvertFrom-Json

    if($regionName.Count -eq 0) {
        Write-Error "Location $locationShortorLong not found"
        exit
    }

    if($regionName.GetType().Name -eq "String") {
        $regionShort = $regionName
    }
    else {
        $regionShort = $regionName[0]
    }

    return $regionShort
}

Export-ModuleMember -Function Get-AzShortRegion 