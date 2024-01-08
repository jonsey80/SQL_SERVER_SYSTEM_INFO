#variables needed for the script
$sqluser = "PSLOGIN"
$sqlpassword = "p@ssword1"
$fileOut = "C:\Temp\System_info.txt"


$computer_name = hostname
$ip_address = Get-NetIPConfiguration|select-object InterfaceAlias,IPv4Address
$OS_Name = $(Get-CimInstance Win32_OperatingSystem).Caption 
$OS_version = $(Get-CimInstance Win32_OperatingSystem).Version 
$Sytem_Ram = $(Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory 
$System_Ram_GB = [Math]::Round(($Sytem_Ram/1GB),2)|Out-String 
$processor = $(get-WmiObject Win32_processor).Name
$drive = Get-WmiObject -Class Win32_logicaldisk|     #replace("0","Unknown"),Replace("1","No Root Directory"),Replace("2","Removable Disk"),Replace('3',"Local Disk"),Replace("4","Network Drive"),Replace("5","Compact Disk"),Replace("6","Ram Disk"))
Select-Object -Property DeviceID,  VolumeName, 
@{L='DriveType'; E={($_.DriveType)}},
@{L='FreeSpaceGB';E={"{0:N2}" -f ($_.FreeSpace /1GB)}},
@{L="Capacity";E={"{0:N2}" -f ($_.Size/1GB)}}
$sql_instances = $(get-itemproperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server').InstalledInstances
write-output "Server_Name: $computer_name" | out-file $fileOut 
write-output "Server IP Details: " $ip_address| out-file $fileout -Append
write-output "Operating_system: $os_name  " | out-file $fileOut -Append
write-output "Operating System Version: $os_version "  | out-file $fileOut  -Append
Write-output "Installed Physical Memory: $System_Ram_GB " | out-file $fileOut -Append
Write-Output "System Processor: $processor " | out-file $fileOut -Append
Write-Output "Disk Info:  " $drive | out-file $fileOut -append
Write-Output "SQL Server Instances: $sql_instances " | out-file $fileOut -Append

$instance_Sql = "select @@VERSION"
$dbname_sql = "
SELECT 
    name as [Database name], 
	case when compatibility_level = 100 then 'SQL SERVER 2008'
		when compatibility_level = 110 then 'SQL SERVER 2012'
		when compatibility_level = 120 then 'SQL SERVER 2014'
		when compatibility_level = 130 then 'SQL SERVER 2016'
		when compatibility_level = 140 then 'SQL SERVER 2017'
		else 'unknown version'
	end 'SQL Compatibility level',
	recovery_model_desc,
	is_auto_create_stats_on,
	is_auto_update_stats_on,
    CASE is_published  
        WHEN 0 THEN 'No' 
        ELSE 'Yes' 
        END AS [Is Published], 
    CASE is_merge_published  
        WHEN 0 THEN 'No' 
        ELSE 'Yes' 
        END AS [Is Merge Published], 
    CASE is_distributor  
        WHEN 0 THEN 'No'
        ELSE 'Yes' 
        END AS [Is Distributor], 
    CASE is_subscribed  
        WHEN 0 THEN 'No' 
        ELSE 'Yes' 
        END AS [Is Subscribed],
	CASE
	WHEN B.mirroring_state is NULL THEN 'Mirroring not configured'
	ELSE 'Mirroring configured'
END as MirroringState
FROM sys.databases A
left outer join sys.database_mirroring B
ON A.database_id=B.database_id
WHERE A.database_id > 4 
"

foreach ($instance in $sql_instances) {

write-output "Checking Properties for $instance" | out-file $fileOut -Append
    
    if($instance -eq "MSSQLSERVER") {$instance = "localhost"}
    else {
    $instance = "localhost\$instance"
    }
    
   $instance_details = Invoke-Sqlcmd -serverInstance $instance -Database "master" -username $sqluser -Password $sqlpassword -query $instance_Sql 
   Write-Output "$instance is on version  " $instance_details.Column1| out-file $fileOut -Append
   $DB_NAME = Invoke-Sqlcmd -serverInstance $instance -Database "master" -username $sqluser -Password $sqlpassword -query $dbname_sql
   Write-Output "Databbases on this table: " $DB_NAME| out-file $fileOut -Append

}





