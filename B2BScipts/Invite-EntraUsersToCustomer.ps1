<#
.SYNOPSIS
    Searches for users in Entra ID by company name and job title, then adds them to a specified group.

.DESCRIPTION
    This script connects to Microsoft Graph, and invides users found in CSV file to customer tenant.

.PARAMETER TenantId
    Entra Tenant ID

.PARAMETER FileName
    Entra Tenant ID

.EXAMPLE
    .\Invite-EntraUsersToCustomer.ps1 -TenantId "12345678-1234-1234-1234-123456789abc" -File .\ManagedSOCusers.csv

.NOTES
    Requires Microsoft.Graph PowerShell module
    Requires appropriate permissions: User.Read.All, GroupMember.ReadWrite.All
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$TenantId,

    [Parameter(Mandatory=$true, Position=1)]
    [string]$File
)

# Check if Microsoft.Graph module is installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Users)) {
    Write-Error "Microsoft.Graph.Users module is not installed. Please install it using: Install-Module Microsoft.Graph -Scope CurrentUser"
    exit 1
}

Write-Host "Connecting with Microsoft Graph to TenantId $TenantId" -ForegroundColor Green
Connect-MgGraph -TenantId $TenantId -Scopes 'User.ReadWrite.All', 'Directory.ReadWrite.All' -NoWelcome
$Userlist=Import-Csv $File | select-Object userPrincipalName
foreach ($User in $UserList)
{
    if ($null -eq ((Get-MgUser -all).mail | select-string $user.userPrincipalName)) {
        Write-Host "Inviting $User to tenant $TenantId" -ForegroundColor Green
        New-MgInvitation -InvitedUserDisplayName $user.userPrincipalName -InvitedUserEmailAddress $user.userPrincipalName -InviteRedirectUrl "https://security.microsoft.com/homepage?tid=$tenantID"
    }
    else {
        Write-Host "User" $user.userPrincipalName "already exists, ignoring" -ForegroundColor Cyan
        exit 1
    }
}