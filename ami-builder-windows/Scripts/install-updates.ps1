Write-Host "Installing PSWindowsUpdate Module..." -ForegroundColor Green
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name PSWindowsUpdate -Force -Confirm:$false

Write-Host "Applying Windows Updates..." -ForegroundColor Green
Import-Module PSWindowsUpdate
Get-WindowsUpdate -AcceptAll -Install -AutoReboot
