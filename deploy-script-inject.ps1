param (
    [string]$scriptUrl = $null
)

if ($scriptUrl.Length -eq 0) {
    Write-Host "Parameter -scriptUrl was not provided, and is required."
    return
}

Write-Host "Downloading deploy script $scriptUrl"

$WebClient=New-Object net.webclient
$deployScriptContents = $WebClient.DownloadString($scriptUrl)

Write-Host "Deploy script downloaded"

$csprojFiles = Get-ChildItem -Path  . -Include @("*.csproj", "*.vbproj") -Recurse
foreach ($file in $csprojFiles) {
    [xml]$xmlFile = Get-Content $file.FullName
    $projNode = $xmlFile.SelectSingleNode('//*[local-name()="Project"]')

    if ($projNode -eq $null) {
        Write-Host "Project node is null, can't process $($file.Name)"
        continue
    }

    $deployPath = Join-Path -Path $file.Directory.FullName -ChildPath "deploy.ps1"
    if (Test-Path $deployPath) {
        Write-Host "deploy.ps1 already exists, not adding"
    } else {
        Write-Host "Writing deploy.cs1 to $deployPath"
        $deployScriptContents | Out-File $deployPath
    }

    $targetBeforeBuildNodes = $projNode.SelectNodes('*[local-name()="Target" and @Name="BeforeBuild"]')


    #Write-Host "$($file.FullName) count is $($targetBeforeBuildNodes.Count)"

    $targetNode = $null

    if ($targetBeforeBuildNodes.Count -eq 0) {
        # add the node
        Write-Host "Adding Target BeforeBuild node to project node..."
        $targetNode = $xmlFile.CreateElement("Target", $xmlFile.DocumentElement.NamespaceURI)
        $targetNode.SetAttribute("Name", "BeforeBuild")
        $projNode.AppendChild($targetNode)
    } else {
        $targetNode = $targetBeforeBuildNodes[0]
        Write-Host "Found existing Target BeforeBuild node..."
    }

    $itemGroupNodes = $targetNode.SelectNodes('*[local-name()="ItemGroup"]')
    $itemGroupNode = $null

    if ($itemGroupNodes.Count -eq 0) {
        Write-Host "Adding ItemGroup node to Target BeforeBuild node..."
        $itemGroupNode = $xmlFile.CreateElement("ItemGroup", $xmlFile.DocumentElement.NamespaceURI)
        $targetNode.AppendChild($itemGroupNode)
    } else {
        $itemGroupNode = $itemGroupNodes[0]
        Write-Host "Found existing ItemGroup node..."
    }

    $contentNode = $itemGroupNode.SelectSingleNode('*[local-name()="Content" and @Include="deploy.ps1"]')
    if ($contentNode -eq $null) {
        Write-Host "Adding Content Include deploy.ps1 node to ItemGroup node..."
        $contentNode = $xmlFile.CreateElement("Content", $xmlFile.DocumentElement.NamespaceURI)
        $itemGroupNode.AppendChild($contentNode)
        $contentNode.SetAttribute("Include", "deploy.ps1")
        $xmlFile.Save($file.FullName)    
    } else {
        Write-Host "Content Include deploy.ps1 node already exists, not modifying"
    }
}

