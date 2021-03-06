<#
.Synopsis
   This scripts take a Package (*.cspkg) and config file (*.cscfg) to create a 
   site on Web Role.
.DESCRIPTION
   This sample script demonstrating how deploy a DotNet corporate site into a
    Cloud Services.
	
    At the end of the script it start the browser and shows the site. 
.EXAMPLE
    Use the following to Deploy the project
    $test = & ".\Deploy-AzureCloudService.ps1"  `
        -ServiceName "jpggTest"  `
        -ServiceLocation "West US" `
        -ConfigurationFilePath ".\EnterpiseSite\ServiceConfiguration.Cloud.cscfg" `
        -PackageFilePath ".\EnterpiseSite\WebCorpHolaMundo.Azure.cspkg"

.OUTPUTS
   Write in Host the time spended in the script execution
#>
#1. Parameters
Param(
    #Cloud services Name
    [Parameter(Mandatory = $true)]
    [String]$ServiceName,            
    #Cloud Service location 
    [Parameter(Mandatory = $true)]
    [String]$ServiceLocation,           
    #Path to configuration file (*.cscfg)     
    [Parameter(Mandatory = $true)]                             
    [String]$ConfigurationFilePath,   
    #PackageFilePath:        Path to Package file (*.cspkg)          
    [Parameter(Mandatory = $true)]                             
    [String]$PackageFilePath            
)

<# CreateCloudService
.Synopsis
This function create a Cloud Services if this Cloud Service don't exists.

.DESCRIPTION
    This function try to obtain the services using $MyServiceName. If we have
    an exception it is mean the Cloud services don’t exist and create it.
.EXAMPLE
    CreateCloudService  "ServiceName" "ServiceLocation"
#> 
Function CreateCloudService 
{
 Param(
    #Cloud services Name
    [Parameter(Mandatory = $true)]
    [String]$MyServiceName,
    #Cloud service Location 
    [Parameter(Mandatory = $true)]
    [String]$MyServiceLocation     
    )

 try
 {
    $CloudService = Get-AzureService -ServiceName $MyServiceName
    Write-Verbose ("cloud service {0} in location {1} exist!" -f $MyServiceName, $MyServiceLocation)
 }
 catch
 { 
   #Create
   Write-Verbose ("[Start] creating cloud service {0} in location {1}" -f $MyServiceName, $MyServiceLocation)
   New-AzureService -ServiceName $MyServiceName -Location $MyServiceLocation
   Write-Verbose ("[Finish] creating cloud service {0} in location {1}" -f $MyServiceName, $MyServiceLocation)
 }
}

<# CreateStorage
.Synopsis
This function create a Storage Account if it don't exists.

.DESCRIPTION
This function try to obtain the Storage Account using $MyStorageName. If we have
 an exception it is mean the Storage Account don’t exist and create it.

.OUTPUTS
    Storage Account connectionString
.EXAMPLE
   CreateStorage -MyStorageAccountName $StorageAccountName -MyStorageLocation $ServiceLocation 
#>
Function CreateStorage
{
Param (
    #Storage Account  Name
    [Parameter(Mandatory = $true)]
    [String]$MyStorageAccountName,
    #Storage Account   Location 
    [Parameter(Mandatory = $true)]
    [String]$MyStorageLocation 
)
    try
    {
        $myStorageAccount= Get-AzureStorageAccount -StorageAccountName $MyStorageAccountName
        Write-Verbose ("Storage account {0} in location {1} exist" -f $MyStorageAccountName, $MyStorageLocation)
    }
    catch
    {
        # Create a new storage account
        Write-Verbose ("[Start] creating storage account {0} in location {1}" -f $MyStorageAccountName, $MyStorageLocation)
        New-AzureStorageAccount -StorageAccountName $MyStorageAccountName -Location $MyStorageLocation -Verbose
        Write-Verbose ("[Finish] creating storage account {0} in location {1}" -f $MyStorageAccountName, $MyStorageLocation)
    }

    # Get the access key of the storage account
    $key = Get-AzureStorageKey -StorageAccountName $MyStorageAccountName

    # Generate the connection string of the storage account
    $connectionString ="BlobEndpoint=http://{0}.blob.core.windows.net/;" -f $MyStorageAccountName
    $connectionString =$connectionString + "QueueEndpoint=http://{0}.queue.core.windows.net/;" -f $MyStorageAccountName
    $connectionString =$connectionString + "TableEndpoint=http://{0}.table.core.windows.net/;" -f $MyStorageAccountName
    $connectionString =$connectionString + "AccountName={0};AccountKey={1}" -f $MyStorageAccountName, $key.Primary

    Return @{ConnectionString = $connectionString}
}


<# DeployPackage
.Synopsis
    It deploy service’s  package with his configuration to a Cloud Services 
.DESCRIPTION
    it function try to obtain the Services deployments by name. If exists this deploy is update. In other case,
     it create a Deploy and does the upload.
.EXAMPLE
   DeployPackage -MyServiceName $ServiceName -MyConfigurationFilePath $NewcscfgFilePath -MyPackageFilePath $PackageFilePath         
#>
Function DeployPackage 
{
Param(
    #Cloud Services name
    [Parameter(Mandatory = $true)]
    [String]$MyServiceName,
    #Path to configuration file (*.cscfg)
    [Parameter(Mandatory = $true)]
    [String]$MyConfigurationFilePath,
    #Path to package file (*.cspkg)
    [Parameter(Mandatory = $true)]
    [String]$MyPackageFilePath
)
    Try
    {
        Get-AzureDeployment -ServiceName $MyServiceName
        Write-Verbose ("[Start] Deploy Service {0}  exist, Will update" -f $MyServiceName)
        Set-AzureDeployment `
            -ServiceName $MyServiceName `
            -Slot Production `
            -Configuration $MyConfigurationFilePath `
            -Package $MyPackageFilePath `
            -Mode Simultaneous -Upgrade
        Write-Verbose ("[finish] Deploy Service {0}  exist, Will update" -f $MyServiceName)
    }
    Catch
    {
        Write-Verbose ("[Start] Deploy Service {0} don't exist, Will create" -f $MyServiceName)
        New-AzureDeployment -ServiceName $MyServiceName -Slot Production -Configuration $MyConfigurationFilePath -Package $MyPackageFilePath
        Write-Verbose ("[Finish] Deploy Service {0} don't exist, Will create" -f $MyServiceName)
    }
    
}

<# WaitRoleInstanceReady
.Synopsis
    it wait all role instance are ready
.DESCRIPTION
    Wait until al instance of Role are ready
.EXAMPLE
  WaitRoleInstanceReady $ServiceName
#>
function WaitRoleInstanceReady 
{
Param(
    #Cloud Services name
    [Parameter(Mandatory = $true)]
    [String]$MyServiceName
)
    Write-Verbose ("[Start] Waiting for Instance Ready")
    do
    {
        $MyDeploy = Get-AzureDeployment -ServiceName $MyServiceName  
        foreach ($Instancia in $MyDeploy.RoleInstanceList)
        {
            $switch=$true
            Write-Verbose ("Instance {0} is in state {1}" -f $Instancia.InstanceName, $Instancia.InstanceStatus )
            if ($Instancia.InstanceStatus -ne "ReadyRole")
            {
                $switch=$false
            }
        }
        if (-Not($switch))
        {
            Write-Verbose ("Waiting Azure Deploy running, it status is {0}" -f $MyDeploy.Status)
            Start-Sleep -s 10
        }
        else
        {
            Write-Verbose ("[Finish] Waiting for Instance Ready")
        }
    }
    until ($switch)
}


$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

$SubscriptionName = "Azure MVP MSDN Subscription"

#Add-AzureAccount

Select-AzureSubscription -SubscriptionName $SubscriptionName

# Get the directory of the current script
$ScriptPath = Split-Path -parent $PSCommandPath

# Mark the start time of the script execution
$StartTime = Get-Date

# Define the names of storage account
$ServiceName = $ServiceName.ToLower()
$StorageAccountName = "{0}storage" -f $ServiceName


#creating Windows Azure cloud service environment
Write-Verbose ("[Start] Validating  Azure cloud service environment {0}" -f $ServiceName)
CreateCloudService  $ServiceName $ServiceLocation

# Create a new storage account
$Storage = CreateStorage -MyStorageAccountName $StorageAccountName -MyStorageLocation $ServiceLocation

Set-AzureSubscription -SubscriptionName $SubscriptionName -CurrentStorageAccountName $StorageAccountName

Write-Verbose ("[Finish] creating Azure cloud service environment {0}" -f $ServiceName)


# Deploy Package
DeployPackage -MyServiceName $ServiceName -MyConfigurationFilePath $ConfigurationFilePath -MyPackageFilePath $PackageFilePath


# Wait Role isntances Ready
WaitRoleInstanceReady $ServiceName


# Mark the finish time of the script execution
#    Output the time consumed in seconds
$finishTime = Get-Date

Write-Host ("Total time used (seconds): {0}" -f ($finishTime - $StartTime).TotalSeconds)

# Launch the Site
Start-Process -FilePath ("http://{0}.cloudapp.net" -f $ServiceName)
