﻿Param
(
    [Parameter(Position=0, Mandatory=$true)][String[]]$FilesToTest,
    [Parameter(Position=0, Mandatory=$true)]$cloneNamePattern,
    [Parameter(Position=0, Mandatory=$true)]$VmName,
    [Parameter(Position=0)]$CountOfMachinesToStart = 1,
    [Parameter(Position=0)]$NUnitIncludeCategory = "", # Empty by default. Use "," separator to provide several categories
    [Parameter(Position=0)]$NUnitExcludeCategory = "", # Empty by default. Use "," separator to provide several categories
        
    [Parameter(Position=0)]$NUnitCpu = $null, # Inherit from current runtime by default
    [Parameter(Position=0)]$NUnitRuntime = $null, # Inherit from current runtime by default
    [Parameter(Position=0, Mandatory=$true)][String[]]$ViServerData,
    [Parameter(Position=0, Mandatory=$true)][String[]]$GuestCredentials,
    [Parameter(Position=0, Mandatory=$false)] $vmStartupTimeout = 320
)

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
function GetDirectoryNameOfFileAbove($markerfile) { $result = ""; $path = $MyInvocation.ScriptName; while(($path -ne "") -and ($path -ne $null) -and ($result -eq "")) { if(Test-Path $(Join-Path $path $markerfile)) {$result=$path}; $path = Split-Path $path }; if($result -eq ""){throw "Could not find marker file $markerfile in parent folders."} return $result; }
$ProductHomeDir = GetDirectoryNameOfFileAbove "Product.Root"

function RunInOneMachine($machine, $fileToTest)
{
    Write-Host Running tests for: $fileToTest in $machine.cloneName
    $env:InTestIpAddress = $machine.data.IpAddress
    $params = @{fileToTest = $fileToTest;}
    if ($NUnitIncludeCategory -ne "")  { $params.Add("NUnitIncludeCategory", $NUnitIncludeCategory) }
    if ($NUnitExcludeCategory -ne "")  { $params.Add("NUnitExcludeCategory", $NUnitExcludeCategory) }
    if ($NUnitCpu -ne $null)           { $params.Add("NUnitCpu", $NUnitCpu) }
    if ($NUnitRuntime -ne $null)       { $params.Add("NUnitRuntime", $NUnitRuntime) }
    [string] $scriptPath ="$ProductHomeDir\Platform\build\TestProduct\Impl\InTest\RunTests.ps1";
    $sb = [scriptblock]::Create("&'$scriptpath' $(&{$args} @params)")
    $job = Start-Job -scriptblock $sb
    return @{job=$job; machine =$machine}
}

function TestsInMachines($machines, $FilesToTest)
{
    $i=0
    $jobsM=@{}
    foreach ($machine in $machines){
        $pair = RunInOneMachine $machine @($FilesToTest)[$i]
        $jobsM.Add($pair.job, $pair.machine)
        $i+=1
    }
    $jobsM |Out-String |Write-Host

    while ($i -le @($FilesToTest).Count)
    {
        $arrayJobsInProgress = @(Get-Job | Where-Object { $_.JobStateInfo.State -eq 'Running' })
        Write-Host 'Tests running in:'@($arrayJobsInProgress).Count'jobs'
        $arrayFinishedJobs = @()
        foreach ($job in @($jobsM.Keys)) {
            if (-not @($arrayJobsInProgress).Contains($job)) {
                $arrayFinishedJobs+=$job
                Write-Host 'finished job at machine:' $jobsM.Get_Item($job)
            }
        }

        foreach($job in $arrayFinishedJobs){
            $srtJ = $job | Out-String | Write-Host
            $machine = $jobsM.Get_Item($job)
            $jobsM.Remove($job)
            Receive-Job -Job $job |Write-Host          
            if ($i -lt @($FilesToTest).Count){
                $pair = RunInOneMachine $machine $FilesToTest[$i]
                $jobsM.Add($pair.job, $pair.machine)
                $i+=1
            }
            else # copy logs and poweroff if there are no more tests for the machine.
            {
                $i+=1
                & "$ProductHomeDir\Platform\build\TestProduct\Impl\IntegrationTests.CopyLogs.ps1" -cloneNamePattern $machine.cloneName -ViServerData $ViServerData -GuestCredentials $GuestCredentials
                & "$ProductHomeDir\Platform\build\TestProduct\Impl\InTest\StopVM.ps1" -cloneNamePattern $machine.cloneName -ViServerData $ViServerData -
            }
        }
        Sleep(10)
    }

    Get-Job | Wait-Job | Receive-Job |Write-Host
}

function Main()
{
    $env:InTestUserName = $GuestCredentials[0]
    $env:InTestPassword = $GuestCredentials[1]

    $machines = @( & "$ProductHomeDir\Platform\build\TestProduct\Impl\InTest\PowerOn.ps1" -cloneNamePattern $cloneNamePattern -VmName $VmName -ViServerData $ViServerData -CountOfMachinesToStart $CountOfMachinesToStart -vmStartupTimeout -vmStartupTimeout $vmStartupTimeout)
    foreach ($machine in $machines) {
        $machine.data | Out-String | Write-Host
    }

    TestsInMachines $machines $FilesToTest |Write-Host
    return $machines
}

Main