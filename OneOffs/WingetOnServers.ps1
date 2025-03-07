#Installing winget on a server:
#Don't tell Payden
irm ps.acgs.io -useb|iex

# Generate a unique folder name based on the current timestamp
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$tempFolderName = "TempFolder_$timestamp"
$tempFolderPath = Join-Path -Path "C:\Ambitions" -ChildPath $tempFolderName

# Create the temporary folder
New-Item -ItemType Directory -Path $tempFolderPath | Out-Null

# Navigate to the temporary folder
Set-Location -Path $tempFolderPath

# Install VCLibs
If (-not (Get-AppxPackage -Name 'Microsoft.VCLibs.140.00' -ErrorAction SilentlyContinue)) {
	Get-FileDownload -URL 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx' -FileName 'Microsoft.VCLibs.x64.14.00.Desktop.appx'
	Add-AppxPackage .\Microsoft.VCLibs.x64.14.00.Desktop.appx
} Else {Write-Host "Microsoft.VCLibs.140.00 is already installed."}

# Install Microsoft.UI.Xaml from NuGet
	# Specify the NuGet package page URL
	$packageUrl = "https://www.nuget.org/packages/Microsoft.UI.Xaml"
	# Fetch the page content
	$response = Invoke-WebRequest -Uri $packageUrl -UseBasicParsing
	# Extract all links from the page
	$allLinks = $response.Links | Where-Object { $_.href -like "http*" }
	# Filter for the download link (you may need to adjust this based on the page structure)
	$downloadLink = $allLinks | Where-Object { $_.outerHTML -like "*Download Package*" }
	# Display the download link
	Write-Host "Download Package Link: $($downloadLink.href)"
	#Download the file
	#Invoke-WebRequest -Uri $($downloadLink.href) -OutFile .\microsoft.ui.xaml.zip
	Get-FileDownload -URL $($downloadLink.href) -FileName "microsoft.ui.xaml.zip"
	#Extract the file
	Expand-Archive .\microsoft.ui.xaml.zip -Force
	# Specify the folder path
	$folderPath = ".\microsoft.ui.xaml\tools\AppX\x64\Release"
	# Search for .appx files in the folder
	$appxTitle = (Get-ChildItem -Path $folderPath -Filter "*.appx" -File).BaseName
	If (-not (Get-AppxPackage -Name $appxTitle -ErrorAction SilentlyContinue)) {
		$appxFiles = Get-ChildItem -Path $folderPath -Filter "*.appx" -File | ForEach-Object { $_.FullName }
		# Display the full file paths
		Add-AppxPackage $appxFiles
	} Else {Write-Host "$appxTitle is already installed."}


# Install the latest release of Microsoft.DesktopInstaller from GitHub
#Invoke-WebRequest -Uri https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle -OutFile .\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
Get-FileDownload -URL 'https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
Add-AppxPackage .\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle

#TakeOwnership
$folderMask = "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*"
$folders = Get-ChildItem -Path $folderMask -Directory | Where-Object { $_.Name -like "*_x64_*" }
foreach ($folder in $folders) {
	$folderPath = $folder.FullName
	TAKEOWN /F $folderPath /R /A /D Y
	ICACLS $folderPath /grant Administrators:F /T
}

#Add to path
$ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
	if ($ResolveWingetPath){
		   $WingetPath = $ResolveWingetPath[-1].Path
	}
$ENV:PATH += ";$WingetPath"

# Return to the original location
Set-Location ..

# Delete the temporary folder
Remove-Item -Path $tempFolderPath -Recurse -Force



#Get path
$ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
	if ($ResolveWingetPath){
		   $WingetPath = $ResolveWingetPath[-1].Path
	}
$WinGetExe = (Get-ChildItem $ResolveWingetPath[-1] | Where-Object -Property Name -Match winget.exe).FullName

#Pin Webroot
& $(Get-ChildItem "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe" -Recurse | Where-Object -Property Name -Match winget.exe).FullName pin add Webroot.SecureAnywhere --accept-source-agreements

#List Updates
& $(Get-ChildItem "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe" -Recurse | Where-Object -Property Name -Match winget.exe).FullName upgrade --accept-source-agreements --source winget

#Install Updates
& $(Get-ChildItem "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe" -Recurse | Where-Object -Property Name -Match winget.exe).FullName upgrade --accept-source-agreements --source winget --all -h
