#--- Author : Ali Hojaji ---#

#--*--------------------------------*--#
#---> Implement Data Deduplication <---#
#--*--------------------------------*--#

#--> install required roles on nodes
Invoke-Command CL1-TEST,CL2-TEST { Install-WindowsFeature FS-FileServer,Failover-Clustering,Hyper-V -IncludeAllSubFeature }

#--> validate cluster requirements
Test-Cluster -Node CL1-TEST,CL2-TEST -Include "Storage Spaces Direct","Inventory","Network","System configuration"

#--> create cluster without storage
New-Cluster -Name S2D-TEST -Node CL1-TEST,CL2-TEST -StaticAddress 192.168.1.150 -NoStorage

#--> set cluster quorum
Set-ClusterQuorum -Cluster S2D-TEST -FileShareWitness "\\dc-test\witness"

#--> enable storage spaces direct
Enable-ClusterStorageSpacesDirect -CimSession S2D-TEST -CacheState Disabled

#--> create virtual disk, parition and format volume, add to csv
New-Volume -CimSession S20-TEST -FriendlyName S2DvDisk -StoragePoolFriendlyName S2D* -FileSystem CSVFS_ReFS -Size 100GB


#--> create cluster without storage
New-Cluster -Name S2D-TEST -Node CL1-TEST,CL2-TEST -StaticAddress 192.168.1.150 -NoStorage 

#--> set cluster quorum
Set-ClusterQuorum -Cluster S2D-FKT -FileShareWitness "\\dc-TEST\witness"

#--> enable storage spaces direct
Enable-ClusterStorageSpacesDirect -CimSession S2D-TEST -Autoconfig $false

#--> reset existing disks
Invoke-Command (Get-Cluster -Name S2D-TEST | Get-ClusterNode) {
    Updata-StorageProviderCache
    Get-StoragePool | Where-Object IsPrimordial -eq $false | Set-StoragePool -IsReadOnly:$false -ErrorAction SilentlyContinue
    Get-StoragePool | Where-Object IsPrimordial -eq $false | Get-VirtualDisk | Remove-VirtualDisk -Confirm:$false -ErrorAction SilentlyContinue
    Get-StoragePool | Where-Object IsPrimordial -eq $false | Remove-StoragePool -Confirm:$false -ErrorAction SilentlyContinue
    Get-PhysicalDisk | Reset-PhysicalDisk -ErrorAction SilentlyContinue 
    Get-Disk | Where-Object Number -ne $null | ? IsBoot -ne $true | ? IsSystem -ne $true | ? PartitionStyle -eq RAW | Group -NoElement -Property FriendlyName 
} Sort -Property PsComputerName,Count

#--> create the storage pool
$disks = Get-PhysicalDisk -CimSession S2D-TEST | Where-Object CanPool -eq True
New-StoragePool -CimSession S2D-TEST -StorageSubSystemFriendlyName "*cluster*" -FriendlyName "S2D Pool" -PhysicalDisks $disks

#--> set the mediatype
Invoke-Command CL1-TEST,CL2-TEST { Get-PhysicalDisk | Where-Object Size -eq 50GB | Set-PhysicalDisk -MediaType SSD }
Invoke-Command CL1-TEST,CL2-TEST { Get-PhysicalDisk | Where-Object Size -eq 100GB | Set-PhysicalDisk -MediaType HDD }

#--> create storage tiers
New-StorageTier -CimSession S2D-TEST -StoragePoolFriendlyName S2D* -FriendlyName Capacity -MediaType HDD
New-StorageTier -CimSession S2D-TEST -StoragePoolFriendlyName S2D* -FriendlyName Performance -MediaType SSD

#--> create volume
New-Volume -CimSession S2D-TEST -FriendlyName S2DvDisk -StoragePoolFriendlyName S2D* -FileSystem CSVFS_ReFS -StorageTierFriendlyNames Capacity,Performance -StorageTiers 