# Source - https://stackoverflow.com/a
# Posted by wasif, modified by community. See post 'Timeline' for change history
# Retrieved 2025-11-10, License - CC BY-SA 4.0
if(!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
 Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList "-File `"$($MyInvocation.MyCommand.Path)`"  `"$($MyInvocation.MyCommand.UnboundArguments)`""
 Exit
}
# End of credit
#
echo "Downloading updates to trusted CA-certificates..."
certutil.exe -generateSSTFromWU $env:Temp\roots.sst
echo "Importing the new certificates..."
( Get-ChildItem -Path $env:Temp\roots.sst ) | Import-Certificate -CertStoreLocation Cert:\LocalMachine\Root
echo "Done!"
