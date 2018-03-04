[CmdletBinding()]
param(
    # The path to put our kernel.json folders in
    $KernelFolder,

    # The path where the kernel executables are (should contain at least the 'netcoreapp2.0' or 'net461' folder)
    $InstallPath = $(Split-Path $PSScriptRoot)
)

Write-Warning "The current preview of Jupyter-PowerShell requires a preview release of dotnet $dotnetCLIRequiredVersion"

# Use the .NET Core APIs to determine the current platform; if a runtime
# exception is thrown, we are on FullCLR, not .NET Core.
try {
    $Runtime = [System.Runtime.InteropServices.RuntimeInformation]
    $OSPlatform = [System.Runtime.InteropServices.OSPlatform]

    $IsCoreCLR = $true
    $IsLinux = $Runtime::IsOSPlatform($OSPlatform::Linux)
    $IsOSX = $Runtime::IsOSPlatform($OSPlatform::OSX)
    $IsWindows = $Runtime::IsOSPlatform($OSPlatform::Windows)
} catch {
    # If these are already set read-only, we're on core, and done here
    try {
        $IsCoreCLR = $false
        $IsLinux = $false
        $IsOSX = $false
        $IsWindows = $true
    } catch {
    }
}


if ($IsWindows) {
    if (!$KernelFolder) {
        $KernelFolder = Join-Path $Env:AppData "jupyter\kernels\"
    }
    $Targets = @("Windows", "WindowsPowerShell")
}
if($IsLinux) {
    if (!$KernelFolder) {
        $KernelFolder = "~/.local/share/jupyter/kernels"
    }
    $Targets = @("Linux")
}
if($IsOSX) {
    if (!$KernelFolder) {
        $KernelFolder = "~/Library/Jupyter/kernels"
    }
    $Targets = @("Mac")
}


foreach($target in $Targets) {
    $kernelPath = Join-Path $InstallPath "$target\PowerShell-Kernel.dll"

    if (!(Test-Path $kernelPath)) {
        Write-Warning "
        Can't find the $target PowerShell kernel file in $kernelPath

        Expected the $target kernel to be in the same folder with this script.

        If you're running this from source code, you must first build using build.ps1
        Then you can re-run the copy of this file WITHIN the build output ...
        `n
        "
        continue
    }
    # Necessary for windows only:
    $kernelPath = Resolve-Path $kernelPath
    $kernelPath = $kernelPath -replace "\\", "\\"

    $targetName = if ($target -eq "WindowsPowerShell") { "WindowsPowerShell"  } else { "PowerShell" }
    $kernelFile = Join-Path $kernelFolder "$targetName\kernel.json"

    # Make sure the kernel folder exists
    $null = New-Item -Path (Split-Path $kernelFile) -Force -ItemType Directory

    $kernelData = @(
        "{"
        "  ""argv"": ["
        "    ""$kernelPath"","
        "    ""{connection_file}"""
        "  ],"
        "  ""display_name"": ""$targetName"","
        "  ""language"": ""PowerShell"""
        "}"
    ) -join "`n"

    Set-Content -Path $kernelFile -Value $kernelData
}
