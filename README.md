## Scripts in B2BScripts

### Create-B2BUserList.ps1 - Create user list for B2B invitations

Usage:

`.\Create-B2BUserList.ps1 -TenantId 12345678-1234-1234-1234-123456789abc -DepartmentName "Managed SOC" -OutputFile ManagedSOCusers.csv`

### Invite-EntraUsersToCustomer.ps1 - Invite Entra users to remote tenant

Usage:

`.\Invite-EntraUsersToCustomer.ps1 -TenantId "12345678-1234-1234-1234-123456789abc" -File .\ManagedSOCusers.csv`

### Add-EntraUsersToGroup.ps1 - Add B2B users to group based on search filters

Usage:

`.\Add-EntraUsersToGroup.ps1 -TenantId 12345678-1234-1234-1234-123456789abc -CompanyName "Managed SOC" -JobTitle "SOC Analyst" -GroupName "Managed SOC Analysts"`
