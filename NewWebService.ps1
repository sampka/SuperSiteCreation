param([string] $Type = "Midware", [string]$SiteName = "ErrorSite", [string] $AppPoolUser = "ErrorUser",[string] $AppPoolPassword = " ",[string] $EnviromentTier = " ", [string] $username = " ", [string] $password = " ")


$SecurePassword = $password | ConvertTo-SecureString -AsPlainText -Force

$mycreds = New-Object System.Management.Automation.PSCredential ($username, $SecurePassword)


if($SiteName -eq "ErrorSite")
{
$SiteName = Read-Host 'Site Name? '
}

if($AppPoolUser -eq "ErrorUser")
{
$AppPoolUser = Read-Host 'Service Account Name? '
}

if($AppPoolPassword -eq " ")
{
$AppPoolPassword = Read-Host 'Service Account Password? '
}
 
if($EnviromentTier -eq " ")
{
$EnviromentTier = Read-Host '0. Test, 1. Beta, 2. Prod '
}




switch($Type)
{
    QLMidware
    {
        $serverTest = "ql2mwtest1"
        $serverBeta = "ql1mwbeta1", "ql2mwbeta1"
        $serverProd = "ql1mw1", "ql1mw2", "ql1mw3", "ql1mw4", "ql1mw5", "ql2mw1", "ql2mw2", "ql2mw3", "ql2mw4", "ql2mw5"


        $domain = "mi.corp.rockfin.com"
        break;
    }
    DNWeb
    {
       $serverTest = 
        break;
    }
    Midware
    {
        $serverTest = "test1midware1"
        $serverBeta = "Beta1midware1", "Beta2midware1"
        $serverProd = "Prod1midware1", "Prod1midware2", "Prod1midware3", "Prod1midware4", "Prod2midware1", "Prod2midware2", "Prod2midware3", "Prod2midware4"


      
        break;
    }
    IntWeb
    {
        $serverTest = "ql2intwebtest1"
        $serverBeta = "ql2intwebbeta1"
        $serverProd = "ql2intweb1", "ql1intweb1"
    break;

    }
    External45iis
    {
        $serverTest = "test1n45iis1"
        $serverBeta = "beta1n45iis1"
        $serverProd = "prod1n45iis1", "prod2n45iis1"

    break;

    }
    Default
    {
        Write-Host -ForegroundColor red "Invalid Type.  Exiting script."
        exit;
    }
}

if($SiteName -eq "ErrorSite")
{
    Write-Host -ForegroundColor red "Invalid Site.  Exiting script."
    exit;
}



#connect and configure site and app pools

    switch($EnviromentTier)
    {
        0 #Test
        {
           $ServerList = $ServerTest
           Write-Host -ForegroundColor green "Connecting to Test Servers"
           
        }
        1 #Beta
        {
            $ServerList = $ServerBeta
            Write-Host -ForegroundColor green "Connecting to Beta Servers"
         
        }
        2 #Prod
        {
           $ServerList = $ServerProd
           Write-Host -ForegroundColor green "Connecting to Prod Servers"
           
        }
    }
    
    foreach($server in $ServerList)
    {


        
        $FQDN = $Server 
        Write-Host -ForegroundColor green "Creating session for $server..."
        $Session = new-pssession -computername $FQDN -credential $mycreds

   

        switch($EnviromentTier)
        {
            1 #Test
            {
                 # set variables in remote session
                Write-Host -ForegroundColor green "Setting environment in remote server Test..."
                invoke-command -session $Session -scriptblock{
                    param($innerNewSiteName, $innerAppPoolUser, $innerAppPoolPassword)
                    $NewUser = "ap-" + $innerNewSiteName + "T"
                    $NewSite = $innerNewSiteName + "Test"
                    $SecurePassword = "Password1"
                } -ArgumentList $SiteName, $AppPoolUser, $AppPoolPassword               
          
               
            }
            2 #Beta
            {
                # set variables in remote session
                Write-Host -ForegroundColor green "Setting environment in remote server Beta..."
                invoke-command -session $Session -scriptblock{
                    param($innerNewSiteName, $innerAppPoolUser, $innerAppPoolPassword)
                    $NewUser = "ap-" + $innerNewSiteName + "B"
                    $NewSite = $innerNewSiteName + "Beta"
                    $SecurePassword = "Password1"
                } -ArgumentList $SiteName, $AppPoolUser, $AppPoolPassword               
              
            }
            3 #Prod
            {
                   # set variables in remote session
                Write-Host -ForegroundColor green "Setting environment in remote server Prod..."
                invoke-command -session $Session -scriptblock{
                    param($innerNewSiteName, $innerAppPoolUser, $innerAppPoolPassword)
                    $NewUser = "ap-" + $innerNewSiteName
                    $NewSite = $innerNewSiteName
                    $SecurePassword = "Password1"
                } -ArgumentList $SiteName, $AppPoolUser, $AppPoolPassword               
             
                             
             
            }
        }

      

        
        Write-Host -ForegroundColor green "Creating IIS Site Directory..."
        invoke-command -session $Session -scriptblock{
            #Site
            $Path = "C:\Sites\" + $innerNewSiteName
            
           
            if (test-path $Path)
            {
                write-host -ForegroundColor red "The site directory already exists"
            }
            else
            {
                Write-Host -ForegroundColor green "Creating site directory..."
                New-Item $Path -type Directory
                Set-Location C:\windows\System32\inetsrv
                Write-Host -ForegroundColor green "Creating IIS site..."
                .\appcmd.exe add site /name:$innerNewSiteName /physicalPath:$Path /bindings:http/*:80:$NewSite
                Write-Host -ForegroundColor green "Creating AppPool..."
                .\appcmd.exe add apppool /name:$innerNewSiteName /managedRuntimeVersion:v4.0
               
                
               
                
               
           
                              
                $AppPool = "appcmd.exe"
                $AppPoolArguments1 = "set site /site.name:$innerNewSiteName /[path='/'].applicationPool:$innerNewSiteName"
                $AppPoolArguments2 = "set config /section:applicationPools /[name='$innerNewSiteName'].processModel.identityType:SpecificUser /[name='$innerNewSiteName'].processModel.userName:mi\$innerAppPoolUser /[name='$innerNewSiteName'].processModel.password:$innerAppPoolPassword"
                
                Write-Host -ForegroundColor green "Creating Application Pool..."
                Start-Process -FilePath $AppPool -Argumentlist $AppPoolArguments1
             
                Write-Host -ForegroundColor green "Setting Service Account ..."
                Start-Process -FilePath $AppPool -Argumentlist $AppPoolArguments2
             
            }

        }
        
        Write-Host -ForegroundColor green "Ending session for $server..."
        Remove-PSSession $session
        
    }


