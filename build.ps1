# This script will download and build libuv in both debug and
# release configurations.

$PACKAGES_DIRECTORY = Join-Path $PSScriptRoot "packages"
$OUTPUT_DIRECTORY   = Join-Path $PSScriptRoot "bin"
$VERSION            = "0.0.0"

if (Test-Path Env:\APPVEYOR_BUILD_VERSION) {
    $VERSION = $env:APPVEYOR_BUILD_VERSION
}

# libuv configuration section
$LIBUV_VERSION      = "1.4.2"
$LIBUV_DIRECTORY    = Join-Path $PACKAGES_DIRECTORY "libuv-$LIBUV_VERSION"
$LIBUV_PACKAGE_FILE = "libuv-$LIBUV_VERSION.zip"
$LIBUV_DOWNLOAD_URL = "https://github.com/libuv/libuv/archive/v$LIBUV_VERSION.zip"

# Nuget configuration section
$NUGET_FILE         = "nuget.exe"
$NUGET_TOOL         = Join-Path $PACKAGES_DIRECTORY $NUGET_FILE
$NUGET_DOWNLOAD_URL = "https://nuget.org/$NUGET_FILE"

function Download-File {
    param (
        [string]$url,
        [string]$target
    )

    $webClient = new-object System.Net.WebClient
    $webClient.DownloadFile($url, $target)
}

function Extract-File {
    param (
        [string]$file,
        [string]$target
    )

    [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($file, $target)
}

# Create packages directory if it does not exist
if (!(Test-Path $PACKAGES_DIRECTORY)) {
    New-Item -ItemType Directory -Path $PACKAGES_DIRECTORY | Out-Null
}

# Download libuv
if (!(Test-Path (Join-Path $PACKAGES_DIRECTORY $LIBUV_PACKAGE_FILE))) {
    Write-Host "Downloading $LIBUV_PACKAGE_FILE"
    Download-File $LIBUV_DOWNLOAD_URL (Join-Path $PACKAGES_DIRECTORY $LIBUV_PACKAGE_FILE)
}

# Download Nuget
if (!(Test-Path $NUGET_TOOL)) {
    Write-Host "Downloading $NUGET_FILE"
    Download-File $NUGET_DOWNLOAD_URL $NUGET_TOOL
}

# Unpack libuv
if (!(Test-Path $LIBUV_DIRECTORY)) {
    Write-Host "Unpacking $LIBUV_PACKAGE_FILE"
    $tmp = Join-Path $PACKAGES_DIRECTORY $LIBUV_PACKAGE_FILE

    Extract-File (Join-Path $PACKAGES_DIRECTORY $LIBUV_PACKAGE_FILE) $PACKAGES_DIRECTORY
}

# Copy the fixed vcbuild file
Copy-Item .\vcbuild-fixed.bat $LIBUV_DIRECTORY\vcbuild.bat

function Compile-Libuv {
    param (
        [string]$platform,
        [string]$configuration
    )

    Push-Location $LIBUV_DIRECTORY

    .\vcbuild.bat shared $configuration

    Pop-Location
}

function Output-Libuv {
    param (
        [string]$platform,
        [string]$configuration
    )

    pushd $LIBUV_DIRECTORY
    
    $t = Join-Path $OUTPUT_DIRECTORY "$platform\$configuration"
    $out = "$configuration"

    # Copy output files
    xcopy /y "$out\*.lib" "$OUTPUT_DIRECTORY\$platform\lib\$configuration\*"
    xcopy /y "$out\*.dll" "$OUTPUT_DIRECTORY\$platform\bin\$configuration\*"
    xcopy /y "$out\*.pdb" "$OUTPUT_DIRECTORY\$platform\bin\$configuration\*"

    popd
}


Compile-Libuv "win32" "debug"
Output-Libuv  "win32" "debug"

Compile-Libuv "win32" "release"
Output-Libuv  "win32" "release"

# Output headers
xcopy /y "$(Join-Path $LIBUV_DIRECTORY include)\*" "$(Join-Path $OUTPUT_DIRECTORY win32\include)\*" /E

# Package with NuGet

copy hadouken.libuv.nuspec $OUTPUT_DIRECTORY

pushd $OUTPUT_DIRECTORY
Start-Process "$NUGET_TOOL" -ArgumentList "pack hadouken.libuv.nuspec -Properties version=$VERSION" -Wait -NoNewWindow
popd
