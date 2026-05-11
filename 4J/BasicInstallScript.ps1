# Requires -RunAsAdministrator (Running PowerShell as Admin)
# ============================================================
# Dataworks 12.1.430 - Automated Desktop Client Deployment
# ============================================================
# Usage: Run as Administrator on the target machine.
# NOTE: Steps 4-8 and 13 involve GUI prompts that require
#       manual interaction unless the installer supports
#       silent/unattended switches.
# ============================================================

# --- Exit Code Definitions ---
# 0    = Success
# 1001 = Failed to create temp staging folder
# 1002 = Failed to copy zipped installer to temp
# 1003 = Failed to rename .zip to .exe
# 1004 = Failed to create install directory
# 1005 = Installer process failed or returned non-zero
# 1006 = Failed to clean up temp folder
# 1007 = Failed to copy raw installer to install directory
# 1008 = nextregall.cmd failed or returned non-zero
# 1009 = Failed to copy configuration files from DWUpdatePoint
# 1010 = Failed to rename dwchecker.exe
# 1011 = Failed to copy report files
# 1012 = Failed to create desktop shortcut
# ============================================================

# --- Stop on any terminating error ---
$ErrorActionPreference = "Stop"

# --- Configuration Variables (single place to update paths) ---
$networkBase      = "\\falcon\support$\Dataworks\DataworksInstall\All the Files Needed For New Install 12.1.430\Brand New Install Using Installer with Updates Files"
$dwUpdatePoint    = "\\Falcon\Support$\Dataworks\DWUpdatePoint"
$destinyReports   = "\\Destiny\DWUpdatePoint\Reports"
$destinyDWReports = "\\destiny\dataworks\reports"
$tempDir          = "C:\Temp\DataworksInstall"
$installDir       = "C:\Dataworks\Next"
$reportsDir       = "$installDir\Reports"
$publicDesktop    = "C:\Users\Public\Desktop"
$installerName    = "install_jack12_1_430_1.exe"
$localExe         = "$tempDir\$installerName"
$localZip         = "$localExe.zip"

# ============================================================
# STEP 0: Create the temp staging folder
# ============================================================
try {
    Write-Host "[Step 0] Creating temp staging folder: $tempDir" -ForegroundColor Cyan
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
} catch {
    Write-Host "[FATAL] Failed to create temp folder: $_" -ForegroundColor Red
    exit 1001
}

# ============================================================
# STEP 1: Copy the zipped installer to the temp folder
# ============================================================
try {
    Write-Host "[Step 1] Copying zipped installer to $tempDir..." -ForegroundColor Cyan
    Copy-Item -Path "$networkBase\$installerName.zip" -Destination $tempDir -Force
} catch {
    Write-Host "[FATAL] Failed to copy zipped installer: $_" -ForegroundColor Red
    exit 1002
}

# ============================================================
# STEP 2: Remove the .zip extension (reveals the .exe)
# ============================================================
try {
    Write-Host "[Step 2] Renaming to remove .zip extension..." -ForegroundColor Cyan
    Rename-Item -Path $localZip -NewName $installerName -Force
} catch {
    Write-Host "[FATAL] Failed to rename zip: $_" -ForegroundColor Red
    exit 1003
}

# ============================================================
# STEP 3-8: Create install directory and run the installer
# ============================================================
try {
    Write-Host "[Step 3] Creating install directory: $installDir" -ForegroundColor Cyan
    New-Item -Path $installDir -ItemType Directory -Force | Out-Null
} catch {
    Write-Host "[FATAL] Failed to create install directory: $_" -ForegroundColor Red
    exit 1004
}

# Launch the installer -- GUI prompts will appear
Write-Host "[Steps 4-8] Launching installer. MANUAL INPUT REQUIRED:" -ForegroundColor Yellow
Write-Host "   -> Enter the installation password when prompted" -ForegroundColor Yellow
Write-Host "   -> Select 'Desktop Client' as the install type" -ForegroundColor Yellow
Write-Host "   -> Set the install folder to: $installDir" -ForegroundColor Yellow
Write-Host "   -> Click 'Okay' on all subsequent PowerShell prompts" -ForegroundColor Yellow

try {
    # -Wait pauses the script until the installer process exits
    # -PassThru gives us the process object so we can check ExitCode
    $installerProc = Start-Process -FilePath $localExe -Wait -PassThru

    if ($installerProc.ExitCode -ne 0) {
        Write-Host "[FATAL] Installer exited with code $($installerProc.ExitCode)" -ForegroundColor Red
        exit 1005
    }
} catch {
    Write-Host "[FATAL] Installer failed to launch or run: $_" -ForegroundColor Red
    exit 1005
}

# ============================================================
# STEP 9: Clean up the temp folder entirely
# ============================================================
try {
    Write-Host "[Step 9] Removing temp staging folder: $tempDir..." -ForegroundColor Cyan
    Remove-Item -Path $tempDir -Recurse -Force
} catch {
    # Non-fatal -- warn but continue since the install itself succeeded
    Write-Host "[WARN] Failed to remove temp folder: $_" -ForegroundColor Yellow
    Write-Host "   -> Continuing anyway. You may want to manually delete $tempDir" -ForegroundColor Yellow
}

# ============================================================
# STEP 10: Copy the raw installer .exe into the install dir
# ============================================================
try {
    Write-Host "[Step 10] Copying $installerName to $installDir..." -ForegroundColor Cyan
    Copy-Item -Path "$networkBase\$installerName" -Destination $installDir -Force
} catch {
    Write-Host "[FATAL] Failed to copy installer to install dir: $_" -ForegroundColor Red
    exit 1007
}

# ============================================================
# STEPS 11-13: Run nextregall.cmd for registry configuration
# ============================================================
Write-Host "[Steps 11-13] Running nextregall.cmd..." -ForegroundColor Yellow
Write-Host "   -> Click 'Okay' on any prompts that appear" -ForegroundColor Yellow

try {
    $regProc = Start-Process -FilePath "cmd.exe" `
        -ArgumentList "/c `"cd /d $installDir && nextregall.cmd`"" `
        -Wait -PassThru

    if ($regProc.ExitCode -ne 0) {
        Write-Host "[FATAL] nextregall.cmd exited with code $($regProc.ExitCode)" -ForegroundColor Red
        exit 1008
    }
} catch {
    Write-Host "[FATAL] nextregall.cmd failed to run: $_" -ForegroundColor Red
    exit 1008
}

# ============================================================
# STEP 14: Copy configuration files from DWUpdatePoint
# ============================================================
Write-Host "[Step 14] Copying configuration files from DWUpdatePoint..." -ForegroundColor Cyan

$configFiles = @("Main.ini", "Snnx.ini", "Snnx_user.exe", "Snnxfapd.apd", "Snnxfapd.FPT")

try {
    $configFiles | ForEach-Object {
        Copy-Item -Path "$dwUpdatePoint\$_" -Destination $installDir -Force
        Write-Host "   -> Copied $_" -ForegroundColor Gray
    }
} catch {
    Write-Host "[FATAL] Failed to copy config files: $_" -ForegroundColor Red
    exit 1009
}

# ============================================================
# STEP 15: Rename dwchecker.exe to disable it (.nod extension)
# ============================================================
Write-Host "[Step 15] Renaming dwchecker.exe to dwchecker.exe.nod..." -ForegroundColor Cyan
$dwChecker = "$installDir\dwchecker.exe"

try {
    if (Test-Path $dwChecker) {
        Rename-Item -Path $dwChecker -NewName "dwchecker.exe.nod" -Force
    } else {
        Write-Host "   -> WARNING: dwchecker.exe not found -- skipping rename" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[FATAL] Failed to rename dwchecker.exe: $_" -ForegroundColor Red
    exit 1010
}

# ============================================================
# STEP 16: Copy report files to C:\Dataworks\Next\Reports
# ============================================================
Write-Host "[Step 16] Copying report files..." -ForegroundColor Cyan

try {
    # Ensure the Reports directory exists
    New-Item -Path $reportsDir -ItemType Directory -Force | Out-Null

    # 16a: Bulk copy all reports from \\destiny\dataworks\reports
    Copy-Item -Path "$destinyDWReports\*" -Destination $reportsDir -Force -Recurse
    Write-Host "   -> Copied all files from $destinyDWReports" -ForegroundColor Gray

    # 16b: Copy the specific netlogin .fxp files from \\Destiny\DWUpdatePoint\Reports
    @(
        "netlogin_ok - renamed by vault professional (1).fxp",
        "netlogin_ok - renamed by vault professional (2).fxp",
        "netlogin_ok - renamed by vault professional.fxp",
        "Netlogin_ok.fxp"
    ) | ForEach-Object {
        Copy-Item -Path "$destinyReports\$_" -Destination $reportsDir -Force
        Write-Host "   -> Copied $_" -ForegroundColor Gray
    }
} catch {
    Write-Host "[FATAL] Failed to copy report files: $_" -ForegroundColor Red
    exit 1011
}

# ============================================================
# STEPS 17-18: Create a "Dataworks" shortcut on Public Desktop
# ============================================================
Write-Host "[Steps 17-18] Creating 'Dataworks' shortcut on Public Desktop..." -ForegroundColor Cyan

try {
    $shell    = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut("$publicDesktop\Dataworks.lnk")
    $shortcut.TargetPath       = "$installDir\snnx_user.exe"
    $shortcut.WorkingDirectory = $installDir
    $shortcut.Description      = "Dataworks 12.1.430 Desktop Client"
    $shortcut.Save()

    # Release the COM object
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
} catch {
    Write-Host "[FATAL] Failed to create desktop shortcut: $_" -ForegroundColor Red
    exit 1012
}

# ============================================================
# DONE
# ============================================================
Write-Host "`n=== Dataworks 12.1.430 deployment complete! ===" -ForegroundColor Green
exit 0
