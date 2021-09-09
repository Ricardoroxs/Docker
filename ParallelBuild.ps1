$cleanUp = {
    docker container kill $(docker ps -q)
    Remove-Item "C:\BuildOutputHost\Windows\AnyCPU\Release\*" -Recurse  
}

$GLOBAL:NUMCONTAINERS = 13;

Function GetSolutions($solutionGroup)
{
    $solutions = @()
    foreach($solutionNode in $solutionGroup.ChildNodes)
    {
        foreach($solution in $solutionNode.ChildNodes)
        {
            $solutions += $solution.Data
        }
    }

    return $solutions
}

Function StartAsync
{
    PARAM
    (
        $BuildProcess,
        $ArgumentsList,
        [switch]$UseShellExecute,
        [switch]$DoNotWaitForExit
    )

    $processes = @{}
    
    foreach($arguments in $ArgumentsList)
    {  
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = (Get-Command $BuildProcess).Source
        $pinfo.Arguments = $arguments.Arguments
        $pinfo.WorkingDirectory = (Get-Location).Path
        $pinfo.WindowStyle = "Hidden"
        $pinfo.UseShellExecute = $UseShellExecute

        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $pinfo
        
        $p.Start() | Out-Null
        $p.PriorityClass = "BelowNormal"
            
        $processes.Add($p,$pinfo.Arguments)
    }

    Write-Host ""

    foreach($proc in $processes.Keys)
    {
        if($DoNotWaitForExit){break;}

        $proc.WaitForExit()
        $processArgument = $processes.Get_Item($proc)
        if($proc.ExitCode -ne 0)
        {
            Start-Job -ScriptBlock $cleanUp            
            Write-Host "Throwing on " $processArgument.ToString()
            throw "An error occured while building!"
        }
        Write-Host "Completed building " $processArgument.ToString()
        $proc.Close()
    }
}

Function StartContainers
{
    PARAM
    (
        $NumContainers,
        $LocalFolder
    )

    $volumePath = "c:\:c:\src"

    $ArgumentsList = @()
    for($i = 0; $i -lt $NumContainers; $i++)
    {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.Arguments = "run","-v",$volumePath,"--rm","-it","-d","--name","container$i","25_deltav_servercore"
        $ArgumentsList += $pinfo
    }
    StartAsync -BuildProcess "docker" -ArgumentsList $ArgumentsList -UseShellExecute
}

Function StartContainerBuilds($solutionsToBuild)
{
    $ArgumentsList = @()
    for($i = 0; $i -lt $solutionsToBuild.Length; $i++)
    {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $logName = $solutionsToBuild[$i].Split("\")[-1]
        $pinfo.Arguments = "exec","container$i","MSBuild.exe",$solutionsToBuild[$i],$type,$configType,"-fl","-flp:logfile=C:\src\BuildOutputHost\logs\$logName.log"
        $ArgumentsList += $pinfo
    }
    StartAsync -BuildProcess "docker" -ArgumentsList $ArgumentsList -UseShellExecute
}

Function PruneContainers
{
    $maxRemainingContainerCount = 0
    for($i = $counter; $i -lt $GroupCounter.Count;$i++)
    {
        if($GroupCounter[$i] -gt $maxRemainingContainerCount)
        {
            $maxRemainingContainerCount = $GroupCounter[$i]
        }
    }
    Write-Output "Pruning from ${GLOBAL:NUMCONTAINERS} to Max Remaining Container Count ${maxRemainingContainerCount}"
    $ArgumentsList = @()
    while($GLOBAL:NUMCONTAINERS -gt $maxRemainingContainerCount)
    {
        $GLOBAL:NUMCONTAINERS = $GLOBAL:NUMCONTAINERS - 1

        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.Arguments = "stop","container$GLOBAL:NUMCONTAINERS"
        $ArgumentsList += $pinfo
    }
    StartAsync -BuildProcess "docker" -ArgumentsList $ArgumentsList -UseShellExecute -DoNotWaitForExit
    Write-Output "Pruning complete. Current containers left: ${GLOBAL:NUMCONTAINERS}"
}

#▐▀▀▀▀▀▀▀▀▀▌
#▐ Actions ▌
#▐▄▄▄▄▄▄▄▄▄▌
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
# Set which type of build to perform
$type = "/t:rebuild"
if($clean)
{
    $type = "/t:clean"
}
elseif($rebuild)
{
    $type = "/t:rebuild"
}

# Set whether we're building Debug or Release
$configType = "/property:Configuration=Release"

Remove-Item "C:\BuildOutputHost\logs\*" -Recurse
# Read in the solution groups from SolutionGroups.xml
[xml]$solutionsFile = Get-Content -Path C:\Richard_Internship\CasC\Containers\25_DeltaV_Build\DeltaV_XML.xml

$GLOBAL:NUMCONTAINERS = 1;
$GroupCounter = @()
foreach($solutionGroup in $solutionsFile.Solutions.ChildNodes)
{
    $numSolutions = 0;
    foreach($solutionNode in $solutionGroup.ChildNodes)
    {
        foreach($solution in $solutionNode.ChildNodes)
        {
            $numSolutions += 1
        }
    }
    $GroupCounter += $numSolutions
    if($numSolutions -gt $GLOBAL:NUMCONTAINERS)
    {
        $GLOBAL:NUMCONTAINERS = $numSolutions;
    }
}
Write-Host "Global Num containers:"($GLOBAL:NUMCONTAINERS)

StartContainers -NumContainers $GLOBAL:NUMCONTAINERS -LocalFolder "C:\ClusterStorage\SharedVolume\TestBuild3"

$counter = 0;
foreach($solutionGroup in $solutionsFile.Solutions.ChildNodes)
{
    Write-Host "Building"($solutionGroup.Name)
    $solutions = GetSolutions($solutionGroup)

    StartContainerBuilds($solutions)
    $counter = $counter + 1
    PruneContainers
}

$stopwatch
#docker container kill $(docker ps -q)
