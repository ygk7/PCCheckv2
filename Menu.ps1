# Checking Script
# For safe and local quick-dumping of System logs and files
#
# Author:
# Created by dot-sys under GPL-3.0 license
# This script is not related to any external Project.
#
# Usage:
# Use with Powershell 5.1 and NET 4.0 or higher.
# Running PC Checking Programs, including this script, outside of PC Checks may have impact on the outcome.
# It is advised not to use this on your own.
#
# Version 2.0
# 05 - November - 2024

$ErrorActionPreference = "SilentlyContinue" 

# ===================== Discord-Benachrichtigungen =====================
# Webhook-URL hier eintragen (Server-/Kanaleinstellungen -> Integrationen -> Webhooks)
$DiscordWebhookUrl = "https://discord.com/api/webhooks/1545965631227301948/oBzOz5bcfLwHDuc9dKKjclf0rjR6Ju0hYYuVPqiy0_A8UtkR_YNuJBsBr06p41ISpw1M"
$DiscordCheckerRoleId = "1545933045305966664"

$Global:PCName = $env:COMPUTERNAME
$Global:PSVersionString = $PSVersionTable.PSVersion.ToString()
# Hinweis: Der tatsächlich eingeloggte Discord-Benutzername lässt sich aus einem
# PowerShell-Skript heraus nicht zuverlässig und sicher auslesen (das würde Zugriff
# auf lokale Discord-Zugangsdaten/Tokens erfordern, was ein Sicherheitsrisiko wäre
# und hier bewusst nicht gemacht wird). Falls gewünscht, hier manuell eintragen:
$Global:DiscordUsername = "nicht ermittelbar"

function Send-DiscordNotification {
    param(
        [string]$Title,
        [string]$Description = "",
        [int]$Color = 3447003,
        [switch]$PingRole,
        [array]$ExtraFields = @()
    )

    if ([string]::IsNullOrWhiteSpace($DiscordWebhookUrl) -or $DiscordWebhookUrl -eq "HIER_DEINE_WEBHOOK_URL_EINTRAGEN") {
        return
    }

    $baseFields = @(
        @{ name = "Computername"; value = $Global:PCName; inline = $true },
        @{ name = "PowerShell-Version"; value = $Global:PSVersionString; inline = $true },
        @{ name = "Discordname"; value = $Global:DiscordUsername; inline = $true }
    )

    $embed = @{
        title       = $Title
        description = $Description
        color       = $Color
        fields      = @($baseFields + $ExtraFields)
        timestamp   = (Get-Date).ToUniversalTime().ToString("o")
    }

    $payload = @{ embeds = @($embed) }

    if ($PingRole) {
        $payload["content"] = "<@&$DiscordCheckerRoleId>"
        $payload["allowed_mentions"] = @{ roles = @($DiscordCheckerRoleId) }
    }

    try {
        $json = $payload | ConvertTo-Json -Depth 10
        Invoke-RestMethod -Uri $DiscordWebhookUrl -Method Post -Body $json -ContentType "application/json; charset=utf-8" | Out-Null
    } catch {
        Write-Host "`n[Discord] Benachrichtigung konnte nicht gesendet werden: $($_.Exception.Message)" -ForegroundColor Red
    }
}
# ========================================================================

function Show-MainMenu {
    return Read-Host "`n`n`nChoose a Category:`n
    (1)`t`tChecks`n
    (2)`t`tPrograms`n
    (Clean)`tClean Traces`n
    (0)`t`tClose Script`n`nChoose"
}

function Show-ChecksMenu {
    return Read-Host "`n`n`nChecks Menu:`n
    (1)`tFull Check`n
    (2)`tQuick Check`n
    (3)`tRecording Check`n
    (4)`tAdvanced Filechecking (BETA - Requires Full Check)`n
    (0)`tBack to Main Menu`n`nChoose"
}

function Show-ProgramsMenu {
    return Read-Host "`n`n`nPrograms Menu:`n
    (1)`tDownload CSV File View (by NirSoft)`n
    (2)`tDownload Timeline Explorer (by ygk7)`n
    (3)`tDownload Registry Explorer (by ygk7)`n
    (4)`tDownload Journal Tool (by Echo)`n
    (5)`tDownload WinprefetchView (by NirSoft)`n
    (6)`tDownload System Informer (by Winsider S&S Inc.)`n
    (7)`tDownload Everything (by voidtools)`n
    (0)`tBack to Main Menu`n`nChoose"
}

function CleanTraces {
    Write-Host "`n`nCleaning traces of the Check..." -ForegroundColor yellow
    Write-Host "`rDoes not include installed programs" -ForegroundColor yellow
    Start-Sleep 1
    Get-ChildItem -Path "C:\Temp\Dump" | Remove-Item -Recurse -Force | Out-Null
    Get-ChildItem -Path "C:\Temp\Scripts" -File | Where-Object { $_.Name -ne "Menu.ps1" } | ForEach-Object { Remove-Item -Path $_.FullName -Recurse -Force } | Out-Null
    Send-DiscordNotification -Title "🧹 Bereinigung durchgeführt" -Description "Die Spuren des Checks wurden bereinigt (installierte Programme ausgenommen)." -Color 15105570
    Write-Host "Traces cleaned successfully." -ForegroundColor green
    Write-Host "`n`n`tReturning to Menu in " -NoNewline 
    Write-Host "2 " -NoNewLine -ForegroundColor Magenta
    Write-Host "Seconds`n`n`n" -NoNewline
    Start-Sleep 2
}

function Unzip {
    param(
        [string]$zipFilePath,
        [string]$destinationPath
    )
    Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFilePath, $destinationPath)
}

do {
    Clear-Host
    $mainChoice = Show-MainMenu
    switch ($mainChoice) {
        "1" {
            do {
                Clear-Host
                $checksChoice = Show-ChecksMenu
                switch ($checksChoice) {
                    1 {
                        Write-Host "`n`nPerforming Check..." -ForegroundColor yellow
                        $startTime = Get-Date
                        Send-DiscordNotification -Title "🔎 Full Check gestartet" -Description "Ein Full Check wurde gestartet." -Color 3447003 -PingRole -ExtraFields @(@{ name = "Startzeit"; value = $startTime.ToString("dd.MM.yyyy HH:mm:ss"); inline = $true })
                        try {
                            New-Item -Path "C:\Temp\Scripts" -ItemType Directory -Force | Out-Null
                            New-Item -Path "C:\Temp\Dump" -ItemType Directory -Force | Out-Null
                            Set-Location "C:\temp"
                            Get-ChildItem -Path "C:\Temp\Dump" | Remove-Item -Recurse -Force | Out-Null
                            Get-ChildItem -Path "C:\Temp\Scripts" -File | Where-Object { $_.Name -ne "Menu.ps1" } | ForEach-Object { Remove-Item -Path $_.FullName -Recurse -Force } | Out-Null
                            $urls = @(
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/PCCheck.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/MFT.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/Registry.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/SystemLogs.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/ProcDump.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/Localhost.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/Viewer.html"
                            )
                            $destinationPath = "C:\Temp\Scripts"
                            foreach ($url in $urls) {
                                $fileName = [System.IO.Path]::GetFileName($url)
                                $destinationFile = Join-Path -Path $destinationPath -ChildPath $fileName
                                Invoke-WebRequest -Uri $url -OutFile $destinationFile -ErrorAction Stop
                                if (Test-Path -Path $destinationFile) {
                                    Write-Host "$fileName downloaded successfully."
                                } else {
                                    throw "Datei $fileName wurde nicht heruntergeladen."
                                }
                            }
                            Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
                            Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force
                            & C:\temp\scripts\PCCheck.ps1
                            $endTime = Get-Date
                            Send-DiscordNotification -Title "🔵 Full Check beendet" -Description "Der Full Check wurde abgeschlossen." -Color 3447003 -PingRole -ExtraFields @(
                                @{ name = "Startzeit"; value = $startTime.ToString("dd.MM.yyyy HH:mm:ss"); inline = $true },
                                @{ name = "Endzeit"; value = $endTime.ToString("dd.MM.yyyy HH:mm:ss"); inline = $true },
                                @{ name = "Laufzeit"; value = $endTime.Subtract($startTime).ToString("hh\:mm\:ss"); inline = $true }
                            )
                        } catch {
                            Send-DiscordNotification -Title "🔴 Fehler beim Full Check" -Description "$($_.Exception.Message)" -Color 15158332 -PingRole
                            Write-Host "`n`nFehler beim Full Check: $($_.Exception.Message)" -ForegroundColor red
                        }
                        return
                    }
                    2 {
                        Write-Host "`n`nPerforming Quick Check..." -ForegroundColor yellow
                        $startTime = Get-Date
                        Send-DiscordNotification -Title "🔎 Quick Check gestartet" -Description "Ein Quick Check wurde gestartet." -Color 3447003 -PingRole -ExtraFields @(@{ name = "Startzeit"; value = $startTime.ToString("dd.MM.yyyy HH:mm:ss"); inline = $true })
                        try {
                            New-Item -Path "C:\Temp\Scripts" -ItemType Directory -Force | Out-Null
                            New-Item -Path "C:\Temp\Dump" -ItemType Directory -Force | Out-Null
                            Set-Location "C:\temp"
                            Get-ChildItem -Path "C:\Temp\Dump" | Remove-Item -Recurse -Force | Out-Null
                            Get-ChildItem -Path "C:\Temp\Scripts" -File | Where-Object { $_.Name -ne "Menu.ps1" } | ForEach-Object { Remove-Item -Path $_.FullName -Recurse -Force } | Out-Null
                            $urls = @(
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/PCCheck.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/QuickMFT.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/Registry.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/SystemLogs.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/ProcDump.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/Localhost.ps1",
                                "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/Viewer.html"
                            )
                            $destinationPath = "C:\Temp\Scripts"
                            foreach ($url in $urls) {
                                $fileName = [System.IO.Path]::GetFileName($url)
                                $destinationFile = Join-Path -Path $destinationPath -ChildPath $fileName
                                Invoke-WebRequest -Uri $url -OutFile $destinationFile -ErrorAction Stop
                                if (Test-Path -Path $destinationFile) {
                                    Write-Host "$fileName downloaded successfully."
                                } else {
                                    throw "Datei $fileName wurde nicht heruntergeladen."
                                }
                            }
                            Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
                            Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force
                            & "C:\Temp\Scripts\PCCheck.ps1"
                            $endTime = Get-Date
                            Send-DiscordNotification -Title "🔵 Quick Check beendet" -Description "Der Quick Check wurde abgeschlossen." -Color 3447003 -PingRole -ExtraFields @(
                                @{ name = "Startzeit"; value = $startTime.ToString("dd.MM.yyyy HH:mm:ss"); inline = $true },
                                @{ name = "Endzeit"; value = $endTime.ToString("dd.MM.yyyy HH:mm:ss"); inline = $true },
                                @{ name = "Laufzeit"; value = $endTime.Subtract($startTime).ToString("hh\:mm\:ss"); inline = $true }
                            )
                        } catch {
                            Send-DiscordNotification -Title "🔴 Fehler beim Quick Check" -Description "$($_.Exception.Message)" -Color 15158332 -PingRole
                            Write-Host "`n`nFehler beim Quick Check: $($_.Exception.Message)" -ForegroundColor red
                        }
                        return
                    }
                    3 {
                        Write-Host "`n`nPerforming Recording Check..." -ForegroundColor yellow
                        $startTime = Get-Date
                        Send-DiscordNotification -Title "🔎 Recording Check gestartet" -Description "Ein Recording Check wurde gestartet." -Color 3447003 -PingRole -ExtraFields @(@{ name = "Startzeit"; value = $startTime.ToString("dd.MM.yyyy HH:mm:ss"); inline = $true })
                        try {
                            New-Item -Path "C:\Temp\Scripts" -ItemType Directory -Force | Out-Null
                            New-Item -Path "C:\Temp\Dump" -ItemType Directory -Force | Out-Null
                            Set-Location "C:\temp"
                            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/dot-sys/Recording-Check/master/Recording-Check.ps1" -OutFile "C:\Temp\Scripts\Recording-Check.ps1" -ErrorAction Stop
                            Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
                            Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force
                            Add-MpPreference -ExclusionPath 'C:\Temp' | Out-Null
                            & C:\temp\scripts\Recording-Check.ps1
                            $endTime = Get-Date
                            Send-DiscordNotification -Title "🔵 Recording Check beendet" -Description "Der Recording Check wurde abgeschlossen." -Color 3447003 -PingRole -ExtraFields @(
                                @{ name = "Startzeit"; value = $startTime.ToString("dd.MM.yyyy HH:mm:ss"); inline = $true },
                                @{ name = "Endzeit"; value = $endTime.ToString("dd.MM.yyyy HH:mm:ss"); inline = $true },
                                @{ name = "Laufzeit"; value = $endTime.Subtract($startTime).ToString("hh\:mm\:ss"); inline = $true }
                            )
                        } catch {
                            Send-DiscordNotification -Title "🔴 Fehler beim Recording Check" -Description "$($_.Exception.Message)" -Color 15158332 -PingRole
                            Write-Host "`n`nFehler beim Recording Check: $($_.Exception.Message)" -ForegroundColor red
                        }
                        Start-Sleep 3
                        & C:\temp\scripts\Menu.ps1
                        return
                    }
                    4 {
                        Write-Host "`n`nPerforming Advanced Filechecking (BETA)..." -ForegroundColor yellow
                        $startTime = Get-Date
                        Send-DiscordNotification -Title "🔎 Advanced Filechecking gestartet" -Description "Ein Advanced Filechecking (BETA) wurde gestartet." -Color 3447003 -PingRole -ExtraFields @(@{ name = "Startzeit"; value = $startTime.ToString("dd.MM.yyyy HH:mm:ss"); inline = $true })
                        try {
                            New-Item -Path "C:\Temp\Scripts" -ItemType Directory -Force | Out-Null
                            Set-Location "C:\temp"
                            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/dot-sys/PCCheckv2/master/Packers.ps1" -OutFile "C:\Temp\Scripts\Packers.ps1" -ErrorAction Stop
                            Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
                            & C:\Temp\Scripts\Packers.ps1
                            $endTime = Get-Date
                            Send-DiscordNotification -Title "🔵 Advanced Filechecking beendet" -Description "Das Advanced Filechecking (BETA) wurde abgeschlossen." -Color 3447003 -PingRole -ExtraFields @(
                                @{ name = "Startzeit"; value = $startTime.ToString("dd.MM.yyyy HH:mm:ss"); inline = $true },
                                @{ name = "Endzeit"; value = $endTime.ToString("dd.MM.yyyy HH:mm:ss"); inline = $true },
                                @{ name = "Laufzeit"; value = $endTime.Subtract($startTime).ToString("hh\:mm\:ss"); inline = $true }
                            )
                        } catch {
                            Send-DiscordNotification -Title "🔴 Fehler beim Advanced Filechecking" -Description "$($_.Exception.Message)" -Color 15158332 -PingRole
                            Write-Host "`n`nFehler beim Advanced Filechecking: $($_.Exception.Message)" -ForegroundColor red
                        }
                        return
                    }
                    0 { break }
                    default {
                        Write-Host "`n`nInvalid option selected. Returning to Checks Menu." -ForegroundColor red
                        Start-Sleep 3
                    }
                }
            } while ($checksChoice -ne 0)
        }
        "2" {
            do {
                Clear-Host
                $programsChoice = Show-ProgramsMenu
                switch ($programsChoice) {
                    1 {
                        Write-Host "`n`nDownloading CSVFileView..." -ForegroundColor yellow
                        (New-Object System.Net.WebClient).DownloadFile("https://www.nirsoft.net/utils/csvfileview-x64.zip", "C:\temp\dump\CSVFileView.zip")
                        Unzip -zipFilePath "C:\temp\dump\CSVFileView.zip" -destinationPath "C:\temp\dump\CSVFileView"
                        Write-Host "CSVFileView downloaded and extracted successfully. Returning to Programs Menu." -ForegroundColor green
                        Start-Sleep 5
                    }
                    2 {
                        Write-Host "`n`nDownloading Timeline Explorer..." -ForegroundColor yellow
                        (New-Object System.Net.WebClient).DownloadFile("https://download.mikestammer.com/net6/TimelineExplorer.zip", "C:\temp\dump\TimelineExplorer.zip")
                        Unzip -zipFilePath "C:\temp\dump\TimelineExplorer.zip" -destinationPath "C:\temp\dump\TimelineExplorer"
                        Write-Host "Timeline Explorer downloaded and extracted successfully. Returning to Programs Menu." -ForegroundColor green
                        Start-Sleep 5
                    }
                    3 {
                        Write-Host "`n`nDownloading Registry Explorer..." -ForegroundColor yellow
                        (New-Object System.Net.WebClient).DownloadFile("https://download.mikestammer.com/net6/RegistryExplorer.zip", "C:\temp\dump\RegistryExplorer.zip")
                        Unzip -zipFilePath "C:\temp\dump\RegistryExplorer.zip" -destinationPath "C:\temp\dump\RegistryExplorer"
                        Write-Host "Registry Explorer downloaded and extracted successfully. Returning to Programs Menu." -ForegroundColor green
                        Start-Sleep 5
                    }
                    4 {
                        Write-Host "`n`nOpening Echo Website" -ForegroundColor yellow
                        Start-Process "http://dl.echo.ac/tool/journal"
                        Write-Host "Echo Website opened. Returning to Programs Menu." -ForegroundColor green
                        Start-Sleep 5
                    }
                    5 {
                        Write-Host "`n`nDownloading WinprefetchView..." -ForegroundColor yellow
                        (New-Object System.Net.WebClient).DownloadFile("https://www.nirsoft.net/utils/winprefetchview.zip", "C:\temp\dump\WinprefetchView.zip")
                        Unzip -zipFilePath "C:\temp\dump\WinprefetchView.zip" -destinationPath "C:\temp\dump\WinprefetchView"
                        Write-Host "WinprefetchView downloaded and extracted successfully. Returning to Programs Menu." -ForegroundColor green
                        Start-Sleep 5
                    }
                    6 {
                        Write-Host "`n`nOpening System Informer Website" -ForegroundColor yellow
                        Start-Process "https://systeminformer.sourceforge.io/canary"
                        Write-Host "System Informer Website opened. Returning to Programs Menu." -ForegroundColor green
                        Start-Sleep 5
                    }
                    7 {
                        Write-Host "`n`nDownloading Everything..." -ForegroundColor yellow
                        (New-Object System.Net.WebClient).DownloadFile("https://www.voidtools.com/Everything-1.4.1.1026.x64-Setup.exe", "C:\temp\dump\Everything.exe")
                        Write-Host "Everything downloaded successfully. Returning to Programs Menu." -ForegroundColor green
                        Start-Sleep 5
                    }
                    0 { break }
                    default {
                        Write-Host "`n`nInvalid option selected. Returning to Programs Menu." -ForegroundColor red
                        Start-Sleep 3
                    }
                }                
            } while ($programsChoice -ne 0)
        }
        "clean" {
            CleanTraces
        }
        "0" {
            Write-Host "`n`nExiting script." -ForegroundColor red
            Send-DiscordNotification -Title "⏹️ Script beendet" -Description "Das Menu-Skript wurde geschlossen." -Color 9807270
            Start-Sleep 2
            Clear-Host
            return
        }
        default {
            Write-Host "`n`nInvalid option selected. Please try again." -ForegroundColor red
            Start-Sleep 2
        }
    }
} while ($mainChoice -ne 0)
