param([string] $Type = "ErrorEnviroment", [string] $NewUser = "ErrorSite")


function errorCheck {
    param($result)
    if($result.Errors.length -gt 0){
        "The following errors were received:"
        $result.Errors[0]
        exit
    }
}

function findFieldId {
    param($template, [string]$name)
    $template.Fields | ForEach-Object {
      
        if ($_.DisplayName -eq $name) {
            $fieldid = $_.Id
           # write-host $_.DisplayName
            return $_.Id
        }
    }
    if ($fieldid -eq $null) {
        Write-Host "No matching field ID was found."
        exit
    }
}

function findTemplate {
    param($templateType)
   
    $result_temp = $proxy.GetSecretTemplates($token)
   
    errorCheck $result_temp
    $templates = $result_temp.SecretTemplates

    $templates | ForEach-Object {
    
    #write-host $_.Name

        if($_.Name -eq $templateType){
            return $_
        }
    }
    if ($templates.length -lt 1) {
        Write-Host "No matching Secret template was found."
        exit
    }
}

function findFolderId {
    param($folderName)
    $result_folder = $proxy.SearchFolders($token, $folderName)
    
  #  write-host $result_folder.Folders.TypeId
    
    errorCheck $result_folder
    return $result_folder.Folders[0].Id
}

function CreateNewSecret {
    param($token, $newFolder, $newTemplate, $newDomain, $newUser, $newPassword, $folderId, $mycreds, $newType, $internalUser, $enviroment, $intusername, $inttextpassword)

  


    
    $template = findTemplate $newTemplate

    # if no password is provided, generate a new password
    if($newPassword.length -lt 1)
    {
       # Write-Host "Password being Generated..."
        $pwdId = (findFieldId $template "Password")
        $result_pwd = $proxy.GeneratePassword($token, $pwdId)
        errorCheck $result_pwd
        $newPassword = $result_pwd.GeneratedPassword
       # write-host $newPassword
   
    }

    # ensure you are including ALL Secret fields here, even if they are empty
    $secretItemFields = ((findFieldId $template "Domain"), (findFieldId $template "Username"), (findFieldId $template "Password"), (findFieldId $template "Notes"))
    
    $secretItemValues = ($newDomain, $newUser, $newPassword, "")

   
    
    $securepassword = ConvertTo-SecureString $newPassword -AsPlainText -Force
   
    
    $secretName = $newUser


    try
    {
    
    new-aduser -name "$newUser" -SamAccountName "$newUser" -GivenName "$newUser" -DisplayName "$newUser" -UserPrincipalName ("$newUser" + '@mi.corp.rockfin.com') -AccountPassword $securepassword -changepasswordatlogon $false -passwordneverexpires $true -Path 'OU=Service,DC=mi,DC=corp,DC=rockfin,DC=com' -enabled $true -Credential $mycreds

    $result_add = $proxy.AddSecret($token, $template.Id, $secretName, $secretItemFields, $secretItemValues, $folderId)
    
    errorCheck $result_add
    
    Write-Host "Secret $secretName has been created."

    $updateSecret = $result_add.secret

    
    }
    catch
    {
    write-host "Account Creation failed :("
    }

   # $argumentlist = '-Type '+ $newType,'-SiteName '+$internalUser,'-AppPooluser '+$newUser,'-AppPoolPassword "'+$newPassword+'"','-EnviromentTier 1'

    $quotepassword = "'+$newPassword+'"


   Start-Process powershell.exe -ArgumentList '-NoExit ', '.\NewWebService.ps1', $newType, $internalUser, $newUser, $quotepassword, $enviroment, $intusername, $inttextpassword


  # \\MI\DFS\USERS\SKaufman\Desktop\Scripts\PowerShell\SuperSiteCreationScripts\NewWebService.ps1 $argumentlist

    


   <# 
    Write-Host "`nEnabling Requires Approval for Access..."
    
    # set IsChangeToSettings to be true to put changes in effect
    $updateSecret.SecretSettings.IsChangeToSettings = 1
    
    # enable request approval and specify approver(s)
    $updateSecret.SecretSettings.RequiresApprovalForAccess = 1

    $type = $proxy.GetType().GetMethod("UpdateSecretPermission").GetParameters()[2].ParameterType.FullName
    
    $userRecord1 = New-Object -TypeName $type
    $userRecord2 = New-Object -TypeName $type

    $userRecord1.UserId = 3
    $userRecord1.GroupId = $null
    $userRecord1.IsUser = $true
    $userRecord2.UserId = $null
    $userRecord2.GroupId = 10
    $userRecord2.IsUser = $false
    
    $updateSecret.SecretSettings.Approvers = @($userRecord1, $userRecord2)
    
    $result_update = $proxy.UpdateSecret($token, $updateSecret)
    errorCheck $result_update
    
    Write-Host "Require Approval enabled.`n"
    #>
  
    return $newPassword

}


if($Type -eq "ErrorEnviroment")
{

$Type = Read-Host "What Server group is this for?"


}


# provide new account information, including the destination folder and template type


switch($Type)
{
 Midware
    {
        $newFolder = 'Prod Domain Applications'
        break;
    }
 Intweb
    {
        $newFolder = 'Internal Applications'
        break;

    }
  External45iis
  {
       $newFolder = 'Prod Domain Applications'
        break;
  }
  QLMidware
  {
   $newFolder = 'Prod Domain Applications'
        break;
  }
  default
  {
  write-host "Invalid Server group"
  break;
  }
 
}



$newTemplate = 'Active Directory Account'
$newDomain = 'mi'

# leave password blank to generate a new one
$newPassword = ''



  # login info
    $url = 'https://secretserver/webservices/sswebservice.asmx'
    $username = read-host "Enter your Secret Server username"
    $password = read-host "Password" -AsSecureString
    $domain = 'mi'   # leave blank for local users
    $proxy = New-WebServiceProxy -uri $url -UseDefaultCredential

    # authenticate to Secret Server
    Write-Host "`nAuthenticating..."
    $BSTR = `
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    $result_auth = $proxy.Authenticate($username, [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR), '',$domain)
    errorCheck $result_auth
    Write-Host "Authentication Successful."



    # obtain token
    $token = $result_auth.Token

  
 

$newUser = Read-host 'Site Name'



#create users
######
$clean = [boolean] 1

$searchUser = "User Not Found"
$NewUsers = new-object String[] 3
$NewUsers[0] = "ap-" + $newUser + "T"
$NewUsers[1] = "ap-" + $newUser + "B"
$NewUsers[2] = "ap-" + $newUser
$ADComputer = "ql1dc2.mi.corp.rockfin.com"
$ADDomain = [ADSI]"WinNT://$ADComputer"
$ADDomain =[ADSI]"LDAP://ldapquery.rockfin.com"

$mycreds = New-Object System.Management.Automation.PSCredential ($username, $password)

$textpassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)


for($index=0; $index -lt 3; $index++)
{
    try
    {
        $searchUser = Get-ADUser -Identity $NewUsers[$index] | Out-Null
    }
    catch
    {
        $searchUser = "User Doesnt Exsist"
        
    }
    
    if($searchUser -eq $null)
    {
        write-host "Error $NewUsers[$index] already exists"
        $clean = [boolean] 0
        
    }
}




if($clean)
{
$folderIdroot = findFolderId $newFolder
$Folder_add = $proxy.FolderCreate($token, $newUser, $folderIdroot, '1')
$folderId = findFolderId $newUser
for($index=0; $index -lt 3; $index++)
    {
    
       $test = CreateNewSecret $token $newFolder $newTemplate $newDomain $NewUsers[$index] $newPassword $folderId $mycreds $Type $NewUser $index $username $textpassword
       
       write-host "Password: $test"
       write-host ''
    }
}
