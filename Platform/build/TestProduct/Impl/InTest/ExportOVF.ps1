param 
(
    [Parameter(Position=0, Mandatory=$true)]$vMname,
       [Parameter(Position=0, Mandatory=$true)]$OVFDest,
    [Parameter(Position=0, Mandatory=$true)][String[]]$ViServerData #"server_adress", "login", "pass"
)

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
function Get-ScriptDirectory { Split-Path $script:MyInvocation.MyCommand.Path }
function GetDirectoryNameOfFileAbove($markerfile) { $result = ""; $path = $MyInvocation.ScriptName; while(($path -ne "") -and ($path -ne $null) -and ($result -eq "")) { if(Test-Path $(Join-Path $path $markerfile)) {$result=$path}; $path = Split-Path $path }; if($result -eq ""){throw "Could not find marker file $markerfile in parent folders."} return $result; }
$ProductHomeDir = GetDirectoryNameOfFileAbove "Product.Root"


function ExportOVF($vm)
{
    $Name = $vm.Name
    Write-Host 'EXport OVF to machine:'$Name
       Try{Get-VM -Name $Name | Export-VApp -Destination $OVFDest -confirm:$false -RunAsync:$false} Catch{}
    sleep 5
}

function Run()
{
    $ViServerAddress = $ViServerData[0]
    $ViServerLogin = $ViServerData[1]
    $ViServerPasword = $ViServerData[2]
    & (Join-Path (Get-ScriptDirectory) "ViServer.Connect.ps1") -ViServerAddress $ViServerAddress -ViServerLogin $ViServerLogin -ViServerPasword $ViServerPasword | Out-Null

       $vms = @(Get-VM -Name $vMname)
    foreach ($vm in $vms)
    {
        ExportOVF $vm
    }

}

Run
