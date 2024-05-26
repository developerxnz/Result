

$authorizationInfo = ""
$projectid = ""
$repository=""
$repositoryId=""
$repositoryPath = ""

$headers = @{Authorization = ('Basic {0}' -f $authorizationInfo)}

function Get-Work-Item-Status {
    
    param (
        $workItemId
    )

    $url = "https://dev.azure.com/{0}/{1}/_apis/wit/workitems/{2}?api-version=7.1-preview.3&fields=System.State" -f $projectid,$repository,$workItemId

    $response = Invoke-RestMethod -Headers $headers -ContentType "application/json" -Method 'Get' -Body $body -URI $url

    $response.fields."System.State"
}

function Get-Pull-Request{

    param (
        $pullRequestId
    )

    $url = "$repositoryPath/pullRequests/$pullRequestId/workitems?api-version=7.1-preview.1"

    $response = Invoke-RestMethod -Headers $headers -ContentType "application/json" -Method 'Get' -Body $body -URI $url

    $response.value[0].id
}
function Get-Pull-Request-Id-By-Commit {

    param (
        $CommitId
    )

    $body = @{
        queries = @(
            @{
                type = "commit"
                items = @(
                    $CommitId
                )
            }
        )   
    } | ConvertTo-Json -Depth 3

    $url = "$repositoryPath/pullrequestquery?api-version=7.1-preview.1"

    $response = Invoke-RestMethod -Headers $headers -ContentType "application/json" -Method 'Post' -Body $body -URI $url

    if($null -eq $response.results[0].$CommitId)
    {
        $null
    }
    else {
        $response.results[0].$CommitId.pullRequestId
    }
}


# Get last 100 log entries as a PowerShell object
$gitHist = (git log --format="%ai`t%H`t%an`t%ae`t%s`tUnknown" -n 10) | ConvertFrom-Csv -Delimiter "`t" -Header ("Date","CommitId","Author","Email","Subject", "Status")

# Now you can do iterate over each commit in PowerShell, group sort etc.
# Example to get a commit top list
#$gitHist|Group-Object -Property Author -NoElement|Sort-Object -Property Count -Descending

# Flow
# 1. Get commits since last tag
# 2. Get PR by Commit Id if there is one.
# 3. Get Work Item Id by Pull Request
# 4. Get Work Item Status

#End output
Write-Host "Deploying : Project Name"
Write-Host "Version: {release}"
Write-Host "Build: {build}"
Write-Host "Roll Back Version: {rollback}"
Write-Host "Release Date: {date}"
Write-Host "Commits:"

function Process-Commits {

    param (
        $log
    )

    $prId = Get-Pull-Request-Id-By-Commit "321ac1970f5e5ef510946e4a597a7e87649f4807" #$log.CommitId 
    
    if($null -eq $prId)
    {
        continue
    }

    $workItemId = Get-Pull-Request $prId
    if($null -eq $workItemId)
    {
        continue
    }

    $status = Get-Work-Item-Status $workItemId

    $log.Status = $status
}

function Create-Release {
    param (
        $log
    )

    Write-Host $log.Date $log.Author
}

$gitHist | ForEach-Object {
    Process-Commits $_
}

$unresolved = $gitHist | Where-Object -Property Status -ne "Resolved"
if($unresolved.length -gt 0 )
{
    Write-Host "Unable to create Release"
}
else
{

    if($gitHist -is [array])
    {
        $gitHist | ForEach-Object {
            Create-Release $_
        }
    }
    else {
        Create-Release $gitHist
    }
    
}

