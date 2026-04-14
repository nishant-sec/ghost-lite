$targets = @("wrk-jbrown", "wrk-rclark", "ATLAS-DC")
$credential = Get-Credential

foreach ($machine in $targets) {
    Write-Host "[*] Deploying to $machine..."
    $session = New-PSSession -ComputerName $machine -Credential $credential -ErrorAction SilentlyContinue

    if (-not $session) {
        Write-Host "  [!] Could not connect to $machine - skipping"
        continue
    }

    if ($machine -ne $env:COMPUTERNAME) {
        # Step 1: Create directories on remote
        Invoke-Command -Session $session -ScriptBlock {
            New-Item -ItemType Directory -Path "C:\GhostsLite" -Force | Out-Null
            New-Item -ItemType Directory -Path "C:\GhostsLite\tools" -Force | Out-Null
        }

        # Step 2: Stop service and copy NSSM
        Write-Host "  [+] Copying NSSM to $machine..."
        Invoke-Command -Session $session -ScriptBlock {
            Stop-Service GhostsLite -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
        Copy-Item -Path "C:\GhostsLite\tools\nssm.exe" `
                  -Destination "C:\GhostsLite\tools\nssm.exe" `
                  -ToSession $session -Force

        # Step 3: Stop existing service if running
        Invoke-Command -Session $session -ScriptBlock {
            C:\GhostsLite\tools\nssm.exe stop GhostsLite 2>$null
            C:\GhostsLite\tools\nssm.exe remove GhostsLite confirm 2>$null
            Start-Sleep -Seconds 2
        }

        # Step 4: Copy GHOSTS Lite files
        Write-Host "  [+] Copying GHOSTS Lite files to $machine..."
        Copy-Item -Path "C:\GhostsLite\ghosts-lite-win\*" `
                  -Destination "C:\GhostsLite" `
                  -ToSession $session `
                  -Recurse -Force

        # Step 5: Copy dotnet-install.ps1 and install .NET 8
        Write-Host "  [+] Copying dotnet-install.ps1 to $machine..."
        Copy-Item -Path "C:\GhostsLite\dotnet-install.ps1" `
                  -Destination "C:\GhostsLite\dotnet-install.ps1" `
                  -ToSession $session -Force

        Write-Host "  [+] Installing .NET 8 Runtime on $machine..."
        Invoke-Command -Session $session -ScriptBlock {
            $dotnetExe = "C:\Program Files\dotnet\dotnet.exe"
            if (-not (Test-Path $dotnetExe)) {
                Write-Host "    Installing .NET 8.0.11..."
                powershell -ExecutionPolicy Bypass -File "C:\GhostsLite\dotnet-install.ps1" `
                    -Runtime dotnet -Version 8.0.11 -Architecture x64 `
                    -InstallDir "C:\Program Files\dotnet"

                Write-Host "    Installing .NET 8.0.25..."
                powershell -ExecutionPolicy Bypass -File "C:\GhostsLite\dotnet-install.ps1" `
                    -Runtime dotnet -Version 8.0.25 -Architecture x64 `
                    -InstallDir "C:\Program Files\dotnet"

                if (Test-Path $dotnetExe) {
                    Write-Host "    dotnet.exe confirmed OK"
                } else {
                    Write-Host "    [!] dotnet.exe still not found"
                }
            } else {
                Write-Host "    .NET 8 already present, skipping."
            }
        }

        # Step 6: Install GhostsLite service
        Write-Host "  [+] Installing GhostsLite service on $machine..."
        Invoke-Command -Session $session -ScriptBlock {
            $dotnetPath = "C:\Program Files\dotnet\dotnet.exe"
            $dllPath    = "C:\GhostsLite\Ghosts.Client.Lite.dll"

            if (-not (Test-Path $dllPath))    { Write-Host "  [!] DLL not found";        return }
            if (-not (Test-Path $dotnetPath)) { Write-Host "  [!] dotnet.exe not found"; return }

            Write-Host "    Using dotnet: $dotnetPath"
            C:\GhostsLite\tools\nssm.exe install GhostsLite $dotnetPath $dllPath
            C:\GhostsLite\tools\nssm.exe set GhostsLite AppDirectory "C:\GhostsLite"
            C:\GhostsLite\tools\nssm.exe set GhostsLite Start SERVICE_AUTO_START
            C:\GhostsLite\tools\nssm.exe start GhostsLite
            Start-Sleep -Seconds 5
        }

    } else {
        Write-Host "  [+] ATLAS-DC is local - copying files and installing service..."

        # Step 1: Stop existing service if running
        C:\GhostsLite\tools\nssm.exe stop GhostsLite 2>$null
        C:\GhostsLite\tools\nssm.exe remove GhostsLite confirm 2>$null
        Start-Sleep -Seconds 2

        # Step 2: Copy ghosts-lite files locally
        Write-Host "  [+] Copying GHOSTS Lite files locally..."
        Copy-Item -Path "C:\GhostsLite\ghosts-lite-win\*" `
                  -Destination "C:\GhostsLite\" `
                  -Recurse -Force

        # Step 3: Install .NET 8 if not present
        Write-Host "  [+] Checking .NET 8 Runtime..."
        $dotnetExe = "C:\Program Files\dotnet\dotnet.exe"
        if (-not (Test-Path $dotnetExe)) {
            Write-Host "    Installing .NET 8.0.11..."
            powershell -ExecutionPolicy Bypass -File "C:\GhostsLite\dotnet-install.ps1" `
                -Runtime dotnet -Version 8.0.11 -Architecture x64 `
                -InstallDir "C:\Program Files\dotnet"

            Write-Host "    Installing .NET 8.0.25..."
            powershell -ExecutionPolicy Bypass -File "C:\GhostsLite\dotnet-install.ps1" `
                -Runtime dotnet -Version 8.0.25 -Architecture x64 `
                -InstallDir "C:\Program Files\dotnet"

            if (Test-Path $dotnetExe) {
                Write-Host "    dotnet.exe confirmed OK"
            } else {
                Write-Host "    [!] dotnet.exe still not found"
            }
        } else {
            Write-Host "    .NET 8 already present, skipping."
        }

        # Step 4: Install service locally
        Write-Host "  [+] Installing GhostsLite service on ATLAS-DC..."
        $dotnetPath = "C:\Program Files\dotnet\dotnet.exe"
        $dllPath    = "C:\GhostsLite\Ghosts.Client.Lite.dll"

        if (-not (Test-Path $dllPath))        { Write-Host "  [!] DLL not found" }
        elseif (-not (Test-Path $dotnetPath)) { Write-Host "  [!] dotnet.exe not found" }
        else {
            Write-Host "    Using dotnet: $dotnetPath"
            C:\GhostsLite\tools\nssm.exe install GhostsLite $dotnetPath $dllPath
            C:\GhostsLite\tools\nssm.exe set GhostsLite AppDirectory "C:\GhostsLite"
            C:\GhostsLite\tools\nssm.exe set GhostsLite Start SERVICE_AUTO_START
            C:\GhostsLite\tools\nssm.exe start GhostsLite
            Start-Sleep -Seconds 5
        }
    }

    $status = Invoke-Command -Session $session -ScriptBlock {
        (Get-Service GhostsLite -ErrorAction SilentlyContinue).Status
    }
    Write-Host "  [+] GhostsLite status on $machine`: $status"
    Remove-PSSession $session
    Write-Host "[*] Done: $machine`n"
}
Write-Host "[*] Deployment complete."
