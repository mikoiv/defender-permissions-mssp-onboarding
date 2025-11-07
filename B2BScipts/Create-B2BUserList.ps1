<#
.SYNOPSIS
    Search Microsoft Entra ID (Azure AD) users by department and export to CSV

.DESCRIPTION
    This script connects to Microsoft Entra ID, searches for users in a specific department,
    and exports the results to a CSV file.

.PARAMETER DepartmentName
    The department name to filter users by

.PARAMETER OutputFile
    Path where the CSV file will be saved (default: current directory)

.EXAMPLE
    .\Create-B2BUserList.ps1 -TenantId "12345678-1234-1234-1234-123456789abc" -DepartmentName "Managed SOC" -OutputFile "ManagedSOCusers.csv"

.NOTES
    Requires Microsoft.Graph PowerShell module
    Install with: Install-Module Microsoft.Graph -Scope CurrentUser
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$TenantId,

    [Parameter(Mandatory=$true)]
    [string]$DepartmentName,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputFile
)

# Check if Microsoft.Graph module is installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Users)) {
    Write-Error "Microsoft.Graph.Users module is not installed. Please install it using: Install-Module Microsoft.Graph -Scope CurrentUser"
    exit 1
}

try {
    Write-Host "Connecting to Microsoft Entra ID..." -ForegroundColor Cyan
    
    # Connect to Microsoft Graph with required permissions
    Connect-MgGraph -TenantId $TenantId -Scopes "User.Read.All" -NoWelcome
    
    Write-Host "Searching for users in department: $DepartmentName" -ForegroundColor Cyan
    
    # Search for users by department
    $users = Get-MgUser -Filter "Department eq '$DepartmentName'" -All -Property `
        DisplayName,
        UserPrincipalName,
        Mail,
        Department,
        JobTitle,
        OfficeLocation,
        City,
        State,
        Country,
        AccountEnabled,
        Id
    
    if ($users.Count -eq 0) {
        Write-Warning "No users found in department: $DepartmentName"
        Disconnect-MgGraph | Out-Null
        exit 0
    }
    
    Write-Host "Found $($users.Count) user(s) in department: $DepartmentName" -ForegroundColor Green
    
    # Prepare data for CSV export
    $exportData = $users | Select-Object `
        DisplayName,
        UserPrincipalName,
        Mail,
        Department,
        JobTitle,
        OfficeLocation,
        City,
        State,
        Country,
        AccountEnabled,
        Id
    
    # Export to CSV
    $exportData | Export-Csv -Path .\$OutputFile -NoTypeInformation -Encoding UTF8
    
    Write-Host "`nResults exported to: $OutputFile" -ForegroundColor Green
    Write-Host "Total users exported: $($users.Count)" -ForegroundColor Green
    
    # Disconnect from Microsoft Graph
    Disconnect-MgGraph | Out-Null
    
} catch {
    Write-Error "An error occurred: $_"
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    exit 1
}