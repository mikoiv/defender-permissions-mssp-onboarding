<#
.SYNOPSIS
    Searches for users in Entra ID by company name and job title, then adds them to a specified group.

.DESCRIPTION
    This script connects to Microsoft Graph, searches for users matching the specified 
    companyName and jobTitle attributes, and adds them to the specified group.

.PARAMETER TenantId
    The Entra Tenant ID

.PARAMETER CompanyName
    The company name to search for

.PARAMETER JobTitle
    The job title to search for

.PARAMETER GroupName
    The name of the group to add users to

.EXAMPLE
    .\Add-EntraUsersToGroup.ps1 -TenantId "12345678-1234-1234-1234-123456789abc" -CompanyName "Contoso" -JobTitle "Developer" -GroupName "DevelopersGroup"

.NOTES
    Requires Microsoft.Graph PowerShell module
    Requires appropriate permissions: User.Read.All, GroupMember.ReadWrite.All
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$TenantId,
    
    [Parameter(Mandatory=$true, Position=1)]
    [string]$CompanyName,
    
    [Parameter(Mandatory=$true, Position=2)]
    [string]$JobTitle,
    
    [Parameter(Mandatory=$true, Position=3)]
    [string]$GroupName
)

# Import required module
try {
    Write-Host "Importing Microsoft Graph modules" -ForegroundColor Cyan
    Import-Module Microsoft.Graph.Users -ErrorAction Stop
    Import-Module Microsoft.Graph.Groups -ErrorAction Stop
    Write-Host "Microsoft Graph modules imported successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to import Microsoft.Graph modules. Please install them using: Install-Module Microsoft.Graph -Scope CurrentUser"
    exit 1
}

# Connect to Microsoft Graph
try {
    Write-Host "Connecting to Microsoft Graph for tenant: $TenantId" -ForegroundColor Cyan
    Connect-MgGraph -TenantId $TenantId -Scopes "User.Read.All", "GroupMember.ReadWrite.All" -NoWelcome -ErrorAction Stop
    Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $_"
    exit 1
}

# Search for users matching the criteria
try {
    Write-Host "`nSearching for B2B users (Guest and Member) with CompanyName='$CompanyName' and JobTitle='$JobTitle'..." -ForegroundColor Cyan
    
    # Filter for B2B users by UPN containing '#EXT#'
    # This captures both B2B Guest and B2B Member users
    Write-Host "Retrieving B2B users from Entra ID (filtering by #EXT# in UPN)..." -ForegroundColor Yellow
    
    # Use startswith filter to get users with #EXT# in their UPN
    # We'll use an approach that gets Guest users, then filter for #EXT# pattern
    $b2bUsers = Get-MgUser -Filter "userType eq 'Guest'" -All `
                           -Property Id,DisplayName,UserPrincipalName,CompanyName,JobTitle,UserType `
                           -ConsistencyLevel eventual
    
    # Also get Member users and filter for #EXT# pattern (B2B Members)
    Write-Host "Checking for B2B Member users..." -ForegroundColor Yellow
    $allMembers = Get-MgUser -Filter "userType eq 'Member'" -All `
                             -Property Id,DisplayName,UserPrincipalName,CompanyName,JobTitle,UserType `
                             -ConsistencyLevel eventual
    
    $b2bMembers = $allMembers | Where-Object { $_.UserPrincipalName -like '*#EXT#*' }
    
    # Combine both B2B Guest and B2B Member users
    $allB2BUsers = @($b2bUsers) + @($b2bMembers)
    
    Write-Host "Found $($b2bUsers.Count) B2B Guest users and $($b2bMembers.Count) B2B Member users" -ForegroundColor Yellow
    Write-Host "Total B2B users: $($allB2BUsers.Count)" -ForegroundColor Yellow
    Write-Host "Filtering by CompanyName and JobTitle..." -ForegroundColor Yellow
    
    # Filter users locally based on exact match for CompanyName and JobTitle
    $users = $allB2BUsers | Where-Object { 
        $_.CompanyName -eq $CompanyName -and $_.JobTitle -eq $JobTitle 
    }
    
    if ($users.Count -eq 0) {
        Write-Warning "No B2B users found matching the specified criteria"
        Write-Host "CompanyName: '$CompanyName'" -ForegroundColor White
        Write-Host "JobTitle: '$JobTitle'" -ForegroundColor White
        Write-Host "Total B2B users checked: $($allB2BUsers.Count)" -ForegroundColor White
        Disconnect-MgGraph | Out-Null
        exit 0
    }
    
    Write-Host "Found $($users.Count) B2B user(s) matching the criteria:" -ForegroundColor Green
    foreach ($user in $users) {
        Write-Host "  - $($user.DisplayName) ($($user.UserPrincipalName)) [UserType: $($user.UserType)]" -ForegroundColor White
    }
}
catch {
    Write-Error "Failed to search for users: $_"
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Find the target group
try {
    Write-Host "`nSearching for group: $GroupName" -ForegroundColor Cyan
    
    $group = Get-MgGroup -Filter "displayName eq '$GroupName'" -ErrorAction Stop
    
    if ($null -eq $group) {
        Write-Error "Group '$GroupName' not found"
        Disconnect-MgGraph | Out-Null
        exit 1
    }
    
    if ($group -is [array] -and $group.Count -gt 1) {
        Write-Warning "Multiple groups found with name '$GroupName'. Using the first one: $($group[0].Id)"
        $group = $group[0]
    }
    
    Write-Host "Found group: $($group.DisplayName) (ID: $($group.Id))" -ForegroundColor Green
}
catch {
    Write-Error "Failed to find group: $_"
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Get current group members to avoid duplicate additions
try {
    Write-Host "`nRetrieving current group members..." -ForegroundColor Cyan
    $currentMembers = Get-MgGroupMember -GroupId $group.Id -All | Select-Object -ExpandProperty Id
}
catch {
    Write-Warning "Could not retrieve current group members. Will attempt to add all users."
    $currentMembers = @()
}

# Add users to the group
$addedCount = 0
$skippedCount = 0
$failedCount = 0

Write-Host "`nAdding users to group '$GroupName'..." -ForegroundColor Cyan

foreach ($user in $users) {
    try {
        if ($currentMembers -contains $user.Id) {
            Write-Host "  ⊘ Skipping $($user.DisplayName) - already a member" -ForegroundColor Yellow
            $skippedCount++
        }
        else {
            New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $user.Id -ErrorAction Stop
            Write-Host "  ✓ Added $($user.DisplayName)" -ForegroundColor Green
            $addedCount++
        }
    }
    catch {
        Write-Warning "  ✗ Failed to add $($user.DisplayName): $_"
        $failedCount++
    }
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total users found: $($users.Count)" -ForegroundColor White
Write-Host "Successfully added: $addedCount" -ForegroundColor Green
Write-Host "Skipped (already members): $skippedCount" -ForegroundColor Yellow
Write-Host "Failed: $failedCount" -ForegroundColor $(if($failedCount -gt 0){"Red"}else{"White"})

# Disconnect from Microsoft Graph
Disconnect-MgGraph | Out-Null
Write-Host "`nDisconnected from Microsoft Graph" -ForegroundColor Cyan