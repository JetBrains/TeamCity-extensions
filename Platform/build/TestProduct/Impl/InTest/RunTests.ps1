Param
(
    [Parameter(Position=0)]$NUnitIncludeCategory = "", # Empty by default. Use "," separator to provide several categories
    [Parameter(Position=0)]$NUnitExcludeCategory = "", # Empty by default. Use "," separator to provide several categories
    [Parameter(Position=0, Mandatory=$true)]$fileToTest,
    [Parameter(Position=0, Mandatory=$true)]$nunitexe,
    [Parameter(Position=0, Mandatory=$true)]$ip
)

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
function GetDirectoryNameOfFileAbove($markerfile) { $result = ""; $path = $MyInvocation.ScriptName; while(($path -ne "") -and ($path -ne $null) -and ($result -eq "")) { if(Test-Path $(Join-Path $path $markerfile)) {$result=$path}; $path = Split-Path $path }; if($result -eq ""){throw "Could not find marker file $markerfile in parent folders."} return $result; }

$ProductHomeDir = GetDirectoryNameOfFileAbove "Product.Root"

$NUnitIncludeCategory = $NUnitIncludeCategory -join ","
$NUnitExcludeCategory = $NUnitExcludeCategory -join ","

function RunIntegrationTests
{
    Write-Host -BackgroundColor Gray -ForegroundColor DarkBlue " + $fileToTest"

    # which NUnit to use
    Import-Module "$ProductHomeDir\Platform\build\TestProduct\Impl\NUnit.psm1"  
    
    #*******************************************************************************
    Write-Host "TRY NET USE with ip " $ip
    
    & net use * /DELETE /Y
    & net use x: \\$ip\C$ "123" /USER:user | Out-String | Write-Host

    & robocopy `"C:\Build Agent\bin`" `"X:\Build Agent\bin`" /E | Out-String | Write-Host
    & robocopy `"C:\Build Agent\conf`" `"X:\Build Agentconf`" /E | Out-String | Write-Host
    & robocopy `"C:\Build Agent\contrlib`" `"X:\Build Agent\contrlib`" /E | Out-String | Write-Host
    & robocopy `"C:\Build Agent\launcher`" `"X:\Build Agent\launcher`" /E | Out-String | Write-Host
    & robocopy `"C:\Build Agent\lib`" `"X:\Build Agent\lib`" /E | Out-String | Write-Host
    & robocopy `"C:\Build Agent\logs`" `"X:\Build Agent\logs`" /E | Out-String | Write-Host
    & robocopy `"C:\Build Agent\plugins`" `"X:\Build Agent\plugins`" /E | Out-String | Write-Host
    & robocopy `"C:\Build Agent\system`" `"X:\Build Agent\system`" /E | Out-String | Write-Host
    & robocopy `"C:\Build Agent\temp`" `"X:\Build Agent\temp`" /E | Out-String | Write-Host
    & robocopy `"C:\Build Agent\tools`" `"X:\Build Agent\tools`" /E | Out-String | Write-Host
    & robocopy `"C:\Build Agent\work`" `"X:\Build Agent\work`" /E /MAXAGE:1 | Out-String | Write-Host
    
    #& xcopy /E /I /S /Y `"C:\Build Agent`" `"X:\Build Agent\`" | Out-String | Write-Host
    #& xcopy /E /I /S /Y `"C:\Build Agent`" `"X:\Build Agent\`" | Out-String | Write-Host

    & net use x: /DELETE | Out-String | Write-Host  
    #*******************************************************************************
    
    [scriptblock]$RunNunit = New-NUnitRunner -nunitexe $nunitexe -NUnitIncludeCategory $NUnitIncludeCategory -NUnitExcludeCategory $NUnitExcludeCategory -ip $ip
    Write-Host "Running nunit: "$RunNunit

    ####################
    ## Test!
    try
    {
       & $RunNunit -Dll $fileToTest
    }
    catch
    {
       Write-Warning "NUnit process has failed with error $($_.ToString()), proceeding with other tests"
    }
    
    ############
}

Write-Host (RunIntegrationTests)