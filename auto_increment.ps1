# $content = Get-Content pubspec.yaml
# $versionLine = $content | Where-Object { $_ -match '^version:' }

# if ($versionLine -match '([\d.]+)\+(\d+)') {
#     $version = $matches[1]
#     $build = [int]$matches[2] + 1
#     $newVersionLine = "version: $version+$build"
#     $newContent = $content -replace '^version:.*', $newVersionLine
#     Set-Content pubspec.yaml $newContent
#     Write-Output "Updated to $newVersionLine"
# }



# Read the pubspec.yaml content
$content = Get-Content pubspec.yaml
$versionLine = $content | Where-Object { $_ -match '^version:' }

if ($versionLine -match '([\d]+)\.([\d]+)\.([\d]+)\+(\d+)') {
    $major = [int]$matches[1]
    $minor = [int]$matches[2]
    $patch = [int]$matches[3]
    $build = [int]$matches[4] + 1  # Always increment build number

    # Optional: Every 10 builds, increase patch version and reset build
    if ($build -gt 10) {
        $patch += 1
        $build = 1
    }

    $newVersionLine = "version: $major.$minor.$patch+$build"
    $newContent = $content -replace '^version:.*', $newVersionLine
    Set-Content pubspec.yaml $newContent
    Write-Output "✅ Updated version to: $newVersionLine"
} else {
    Write-Output "❌ Couldn't match version format in pubspec.yaml"
}
