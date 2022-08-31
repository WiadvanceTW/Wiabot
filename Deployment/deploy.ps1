function WriteInfo {
    param(
        [parameter(mandatory = $true)]
        [string]$message
    )
    Write-Host $message -foregroundcolor white
}

function WriteWarning {
    param(
        [parameter(mandatory = $true)]
        [string]$message
    )
    Write-Host $message -foregroundcolor yellow -BackgroundColor black
}

function WriteSuccess {
    param(
        [parameter(mandatory = $true)]
        [string]$message
    )
    Write-Host $message -foregroundcolor green -BackgroundColor black
}

function WriteError {
    param(
        [parameter(mandatory = $true)]
        [string]$message
    )
    Write-Host $message -foregroundcolor red -BackgroundColor black
}

function IsValidGuid {
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$ObjectGuid
    )

    # Define verification regex
    [regex]$guidRegex = '(?im)^[{(]?[0-9A-F]{8}[-]?(?:[0-9A-F]{4}[-]?){3}[0-9A-F]{12}[)}]?$'

    # Check guid against regex
    return $ObjectGuid -match $guidRegex
}

# Validate input parameters.
function ValidateParameters {
    $isValid = $true
    if (-not(IsValidParameter($parameters.subscriptionId))) {
        WriteError "Invalid subscriptionId."
        $isValid = $false;
    }

    if (-not(IsValidParameter($parameters.subscriptionTenantId)) -or -not(IsValidGuid -ObjectGuid $parameters.subscriptionTenantId.Value)) {
        WriteError "Invalid subscriptionTenantId. This should be a GUID."
        $isValid = $false;
    }

    return $isValid
}

function IsValidParameter {
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory = $true)]
        $param
    )

    return -not([string]::IsNullOrEmpty($param.Value)) -and ($param.Value -ne '<<value>>')
}

function InstallDependencies {
    
    # Check if Azure CLI is installed.
    WriteInfo "Checking if Azure CLI is installed."
    $localPath = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
    if ($null -eq $localPath) {
        $localPath = "C:\Program Files (x86)"
    }

    $localPath = $localPath + "\Microsoft SDKs\Azure\CLI2"
    If (-not(Test-Path -Path $localPath)) {
        WriteWarning "Azure CLI is not installed!"
        $confirmationtitle      = "Please select YES to install Azure CLI."
        $confirmationquestion   = "Do you want to proceed?"
        $confirmationchoices    = "&yes", "&no" # 0 = yes, 1 = no
            
        $updatedecision = $host.ui.promptforchoice($confirmationtitle, $confirmationquestion, $confirmationchoices, 1)
        if ($updatedecision -eq 0) {
            WriteInfo "Installing Azure CLI ..."
            Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
            WriteSuccess "Azure CLI is installed! Please close this PowerShell window and re-run this script in a new PowerShell session."
            EXIT
        } else {
            WriteError "Azure CLI is not installed.`nPlease install the CLI from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest and re-run this script in a new PowerShell session"
            EXIT
        }
    } else {
        WriteSuccess "Azure CLI is installed."
    }
	
	# Installing required modules
    WriteInfo "Checking if the required modules are installed..."
    $isAvailable = $true
    if ((Get-Module -ListAvailable -Name "Az.*")) {
		WriteInfo "Az module is available."
    } else {
        WriteWarning "Az module is missing."
        $isAvailable = $false
    }

    if ((Get-Module -ListAvailable -Name "AzureAD")) {
        WriteInfo "AzureAD module is available."
    } else {
        WriteWarning "AzureAD module is missing."
        $isAvailable = $false
    }

    if ((Get-Module -ListAvailable -Name "WriteAscii")) {
        WriteInfo "WriteAscii module is available."
    } else {
        WriteWarning "WriteAscii module is missing."
        $isAvailable = $false
    }

    if (-not $isAvailable)
    {
        $confirmationTitle = WriteInfo "The script requires the following modules to deploy: `n 1.Az module`n 2.AzureAD module `n 3.WriteAscii module`nIf you proceed, the script will install the missing modules."
        $confirmationQuestion = "Do you want to proceed?"
        $confirmationChoices = "&Yes", "&No" # 0 = Yes, 1 = No
                
        $updateDecision = $Host.UI.PromptForChoice($confirmationTitle, $confirmationQuestion, $confirmationChoices, 1)
        if ($updateDecision -eq 0) {
            if (-not (Get-Module -ListAvailable -Name "Az.*")) {
                WriteInfo "Installing AZ module..."
                Install-Module Az -AllowClobber -Scope CurrentUser
            }

            if (-not (Get-Module -ListAvailable -Name "AzureAD")) {
                WriteInfo "Installing AzureAD module..."
                Install-Module AzureAD -Scope CurrentUser -Force
            }
            
            if (-not (Get-Module -ListAvailable -Name "WriteAscii")) {
                WriteInfo "Installing WriteAscii module..."
                Install-Module WriteAscii -Scope CurrentUser -Force
            }
        } else {
            WriteError "You may install the modules manually by following the below link. Please re-run the script after the modules are installed. `nhttps://docs.microsoft.com/en-us/powershell/module/powershellget/install-module?view=powershell-7"
            EXIT
        }
    } else {
        WriteSuccess "All the modules are available!"
    }
}

# To get the Azure AD app detail. 
function GetAzureADApp {
    param ([Parameter(Mandatory = $true)] [string] $appName)
	WriteInfo "`r`Get Azure AD App: $appName..."
    $app = az ad app list --filter "displayname eq '$appName'" | ConvertFrom-Json
    return $app
}

# Create/re-set Azure AD app.
function CreateAzureADApp {       
	param ([Parameter(Mandatory = $true)] [string] $adAppName)
	try {
        $appSecret = $null;
		
        WriteInfo "`r`Get Azure AD App: $adAppName..."
		$appResult = az ad app list --filter "displayname eq '$adAppName'" | ConvertFrom-Json
		
		if (-not ($appResult)) { 
			az ad app create --display-name $adAppName
			WriteInfo "Waiting for app creation to finish..."
			Start-Sleep -s 10
            WriteSuccess "Azure AD App: $adAppName is created."
			$app = az ad app list --filter "displayname eq '$adAppName'" | ConvertFrom-Json
			$appSecret = az ad app credential reset --id $app.appId --append | ConvertFrom-Json
		} else {
            $appSecret = az ad app credential reset --id $appResult.appId | ConvertFrom-Json
        }

		return $appSecret
    } catch {
        $errorMessage = $_.Exception.Message
        WriteError "Failed to register/configure the Azure AD app. Error message: $errorMessage"
    }
	
	return $null
}

function logout {
    $logOut = az logout
    $disAzAcc = Disconnect-AzAccount
}

# Update manifest file and create a .zip file.
function GenerateAppManifestPackage {
    WriteInfo "`nGenerating package for the app template..."
    
    $sourceManifestPath = "..\Manifest\manifest.json"
    $srcManifestBackupPath = "..\Manifest\manifest_backup.json"
    $destinationZipPath = "..\Manifest\Wiabot-manifest.zip"

    if (!(Test-Path $sourceManifestPath)) {
        throw "$sourceManifestPath does not exist. Please make sure you download the full app template source."
    }

    copy-item -path $sourceManifestPath -destination $srcManifestBackupPath -Force

    # Replace merge fields with proper values in manifest file and save
    $teamsApplication = [guid]::NewGuid()
    $mergeFields = @{
        '<developer name>'   = $parameters.developerName.Value 
        '<bot id>'         = $userAppCred.appId
        '<website url>'    = $parameters.websiteUrl.Value
        '<privacy url>'    = $parameters.privacyUrl.Value
        '<terms of use url>' = $parameters.termsOfUseUrl.Value
        '<app name short>'  = $parameters.appNameShort.Value
        '<app name full>' = $parameters.appNameFull.Value
        '<app description short>' =  $parameters.appDescriptionShort.Value
        '<app description full>' = $parameters.appDescriptionFull.Value
        '<teams application id>'= $teamsApplication.Guid
    }
    
    $appManifestContent = Get-Content $sourceManifestPath
    foreach ($mergeField in $mergeFields.GetEnumerator()) {
        $appManifestContent = $appManifestContent.replace($mergeField.Name, $mergeField.Value)
    }
    
    $appManifestContent | Set-Content $sourceManifestPath -Force

    # Generate zip archive 
    $compressManifest = @{
        LiteralPath      = "..\Manifest\color.png", "..\Manifest\outline.png", $sourceManifestPath
        CompressionLevel = "Fastest"
        DestinationPath  = $destinationZipPath
    }
        
    Compress-Archive @compressManifest -Force

    Remove-Item $sourceManifestPath -ErrorAction Continue

    Rename-Item -Path $srcManifestBackupPath -NewName 'manifest.json'

    WriteSuccess "Package has been created under this path $(Resolve-Path $destinationZipPath)"
}

# ---------------------------------------------------------
# DEPLOYMENT SCRIPT
# ---------------------------------------------------------
	# Check for dependencies and install if needed
    InstallDependencies -ErrorAction Stop
	
	# Load Parameters from JSON meta-data file
    $parametersListContent = Get-Content '.\parameters.json' -ErrorAction Stop
	
    # Validate all the parameters.
    WriteInfo "Validating all the parameters from parameters.json."
    $parameters = $parametersListContent | ConvertFrom-Json
    $parameters

    if (-not(ValidateParameters)) {
        WriteError "Invalid parameters found. Please update the parameters in the parameters.json with valid values and re-run the script."
        EXIT
    }

    # Start Deployment.
    Write-Ascii -InputObject "WiaBot" -ForegroundColor Magenta
    WriteInfo "Starting deployment..."

	# Initialize connections - Azure Az/CLI/Azure AD
    WriteInfo "Login with with your Azure subscription account. Launching Azure sign-in window..."
    Connect-AzAccount -Subscription $parameters.subscriptionId.Value -Tenantid $parameters.subscriptionTenantId.Value -ErrorAction Stop
    $user = az login --tenant $parameters.subscriptionTenantId.value
    if ($LASTEXITCODE -ne 0) {
        WriteError "Login failed for user..."
        EXIT
    }
	
	WriteInfo "Create Azure Resource Group."
	az group create --location $parameters.location.Value --name $parameters.resourceGroupName.Value
	if ($LASTEXITCODE -ne 0) {
        WriteError "Failed to create Azure resource group"
        logout
        EXIT
    }
	
	# Create Application
    $app = $parameters.appName.Value
    $userAppCred = CreateAzureADApp $app
    if ($null -eq $userAppCred) {
        WriteError "Failed to create or update the app in Azure Active Directory. Exiting..."
		logout
		Exit
    }

	# Create Azure Bot Service
    WriteInfo "Create Azure Bot Service."
	az deployment sub create --location $parameters.location.Value--template-file 'bot-template.json' --parameters "groupLocation=$($parameters.location.Value)" "groupName=$($parameters.resourceGroupName.Value)" "appId=$($userAppCred.appId)" "appSecret=$($userAppCred.password)" "botId=$($parameters.botId.Value)" "botSku=$($parameters.botSku.Value)" "newAppServicePlanName=$($parameters.newAppServicePlanName.Value)" "newWebAppName=$($parameters.newWebAppName.Value)" "newAppServicePlanLocation=$($parameters.newAppServicePlanLocation.Value)" "mysqlHost=$($parameters.mysqlHost.Value)" "mysqlUsername=$($parameters.mysqlUsername.Value)" "mysqlPassword=$($parameters.mysqlPassword.Value)" "mysqlDatabase=$($parameters.mysqlDatabase.Value)" "mysqlPort=$($parameters.mysqlPort.Value)"
    if ($LASTEXITCODE -ne 0) {
        WriteError "Failed to create Azure App Service"
        logout
        EXIT
    }
    
    # Create Azure Bot msteams
    az bot msteams create -n $parameters.botId.Value -g $parameters.resourceGroupName.Value

    WriteInfo "Delete config.zip."
    if (Test-Path('.\config.zip'))
    {
        WriteInfo "config.zip exists."
	    Remove-Item '.\config.zip'
    }

    WriteInfo "Compress source file."
    Compress-Archive -Path ..\Source\* -DestinationPath .\config.zip

    az webapp deployment source config-zip --src '.\config.zip' -g $parameters.resourceGroupName.Value -n $parameters.newWebAppName.Value

    # Function call to generate manifest.zip folder for User and Author. 
    GenerateAppManifestPackage

    # Deployment completed.
    Write-Ascii -InputObject "DEPLOYMENT COMPLETED." -ForegroundColor Green

	logout
    Exit