# generate_manifest.ps1 - Generate manifest.json for Jinx asset distribution
# Run from repository root: powershell -File scripts/generate_manifest.ps1

$ErrorActionPreference = "Stop"

function Get-SHA1Base64($filePath) {
    $hash = Get-FileHash -Algorithm SHA1 $filePath
    $bytes = [byte[]]::new(20)
    for ($i = 0; $i -lt 20; $i++) {
        $bytes[$i] = [byte]::Parse($hash.Hash.Substring($i * 2, 2), 'HexNumber')
    }
    return [Convert]::ToBase64String($bytes)
}

function Get-PackageName($style, $region) {
    return "creaturebar-$style-$($region -replace '_', '-')"
}

$assets = @()

# Root level silhouettes (default package)
Get-ChildItem "assets/silhouettes/*.png" | ForEach-Object {
    $assets += @{
        file = "/assets/silhouettes/$($_.Name)"
        type = "data"
        md5 = Get-SHA1Base64 $_.FullName
        last_commit = [int](Get-Date $_.LastWriteTime -UFormat %s)
        package = "creaturebar-default"
    }
    Write-Host "  Added: assets/silhouettes/$($_.Name) (creaturebar-default)"
}

# Style/region silhouettes
Get-ChildItem "assets/silhouettes/*/*/*.png" | ForEach-Object {
    $parts = $_.FullName -split '[/\\]'
    $style = $parts[-3]
    $region = $parts[-2]
    $package = Get-PackageName $style $region
    $relativePath = "assets/silhouettes/$style/$region/$($_.Name)"

    $assets += @{
        file = "/$relativePath"
        type = "data"
        md5 = Get-SHA1Base64 $_.FullName
        last_commit = [int](Get-Date $_.LastWriteTime -UFormat %s)
        package = $package
    }
    Write-Host "  Added: $relativePath ($package)"
}

# Root level configs (default package)
Get-ChildItem "assets/configs/*.yaml" | ForEach-Object {
    $assets += @{
        file = "/assets/configs/$($_.Name)"
        type = "data"
        md5 = Get-SHA1Base64 $_.FullName
        last_commit = [int](Get-Date $_.LastWriteTime -UFormat %s)
        package = "creaturebar-default"
    }
    Write-Host "  Added: assets/configs/$($_.Name) (creaturebar-default)"
}

# Style/region configs
Get-ChildItem "assets/configs/*/*/*.yaml" | ForEach-Object {
    $parts = $_.FullName -split '[/\\]'
    $style = $parts[-3]
    $region = $parts[-2]
    $package = Get-PackageName $style $region
    $relativePath = "assets/configs/$style/$region/$($_.Name)"

    $assets += @{
        file = "/$relativePath"
        type = "data"
        md5 = Get-SHA1Base64 $_.FullName
        last_commit = [int](Get-Date $_.LastWriteTime -UFormat %s)
        package = $package
    }
    Write-Host "  Added: $relativePath ($package)"
}

# Build manifest
$manifest = @{
    available = $assets
    last_updated = [int](Get-Date -UFormat %s)
}

# Convert to JSON and write
$json = $manifest | ConvertTo-Json -Depth 10
$json | Out-File -Encoding UTF8 "manifest.json"

Write-Host ""
Write-Host ("=" * 60)
Write-Host "Manifest generated: manifest.json"
Write-Host "Total assets: $($assets.Count)"
Write-Host ""

# Summary by package
$packages = $assets | Group-Object package
foreach ($pkg in $packages) {
    $silhouettes = ($pkg.Group | Where-Object { $_.file -like "*silhouettes*" }).Count
    $configs = ($pkg.Group | Where-Object { $_.file -like "*configs*" }).Count
    Write-Host "  $($pkg.Name): $silhouettes silhouettes, $configs configs"
}

Write-Host ""
Write-Host "Last updated: $(Get-Date)"
