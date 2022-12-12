using namespace System.Collections.Generic

param (
    [string]$Path2ServersData_Json,
    [string]$Path2ScopeData_Json
)

function PrintOperationBegin {
    param (
        [string]$string
    )
    Write-Host $string -BackgroundColor DarkYellow -ForegroundColor Black
}

function PrintOperationSuccess {
    param (
        [string]$string
    )
    Write-Host $string -BackgroundColor DarkGreen -ForegroundColor Black
}

function PrintInfo {
    param (
        [string]$string
    )
    Write-Host $string -BackgroundColor Cyan -ForegroundColor White
}

function PrintCheck {
    param (
        [string]$string
    )
    Write-Host $string -BackgroundColor DarkMagenta -ForegroundColor Black
}

function PrintFatal {
    param (
        [string]$string
    )
    Write-Host $string -BackgroundColor Red -ForegroundColor Black
}

function PrintWarning {
    param (
        [string]$string
    )
    Write-Host $string -BackgroundColor Yellow -ForegroundColor Black
}

function PrintNewLine {
    Write-Host ""
}



if (!(Test-Path $Path2ServersData_Json -PathType Leaf)) {
    PrintFatal "Can not find open the servers data file!"
    break
}

if (!(Test-Path $Path2ScopeData_Json -PathType Leaf)) {
    PrintFatal "Can not find open the DHCP scope data file!"
    break
}

Import-Module ActiveDirectory

# $ServersData_help = Get-Content -Raw $Path2ServersData_Json | ConvertFrom-Json
# $ScopeData_help = Get-Content -Raw $Path2ScopeData_Json | ConvertFrom-Json
# $ServersData_Json = @{}
# $ScopeData_Json = @{}

# $ServersData_help.PSObject.Properties | ForEach-Object { $ServersData_Json[$_.Name] = $_.Value }
# $ScopeData_help.PSObject.Properties | ForEach-Object { $ScopeData_Json[$_.Name] = $_.Value }

$ServersData_Json = @{
    FirstServer=@{
        LocalNetworkAddress = "10.0.0.7";
        Ipv4Address         = "169.254.5.44";
        Mask                = "255.0.0.0";
    };

    SecondServer=@{
        LocalNetworkAddress = "10.0.0.1"; 
        Ipv4Address         = "10.0.0.1"; 
        Mask                = "255.0.0.0";
    };
}

$ScopeData_Json = @{
    CommonInfo = @{
        ScopeID         = "10.0.0.0";
        Name            = "Lab4Part5Scope 10.0.0.100-200";
        Description     = "Scope 10.0.0.100-200 created by script on lab 4.";
        LeaseDuration   = "00:01:00";
        State           = "InActive";
    };

    RangeInfo = @{
        StartRange  = "10.0.0.100";
        EndRange    = "10.0.0.200";
        SubnetMask  = "255.0.0.0";
    };

    ExclusionInfo = @{
        StartRange  = "10.0.0.195";
        EndRange    = "10.0.0.200";
    };

    ServersInfo = @{
        DnsAddress      = "10.0.0.7";
        RouterAddress   = "10.0.0.7";
    };

    ReservationInfo = @{
        MACAdress         = "00-01-02-03-04-05";
        ReservedIPAdress  = "10.0.0.199";
        Description       = "Reservation to 10.0.0.199 for MAC 00-01-02-03-04-05";
    };

    PolicyInfo = @{
        Name = "Policy for router via script51";
        Description = "lab 4. DHCP scope level policy for MAC addresses AA-01-02* where router is 10.10.10.10";
        Condition = "OR";
        MacAdresses = @{
            EQ = "EQ";
            NE = "NE";
            AA_01_02_any = "AA-01-02*";
        };
        StartRange  = "10.0.0.100";
        EndRange    = "10.0.0.195";
        FeatureInfo = @{
            Router = @{
                Address = "10.10.10.10";
                OptionID = "3";
            };
        };
    };

    FailoverInfo = @{
        Name = "";
        ComputerName = "";
        PartnerServer = "";
        MaxClientLeadTime = "00:30:00";
        StateSwitchInterval = "00:01:00";
        AutoStateTransition = $True;
        ReservePercent = "35";
        SharedSecret = "123";
    };
}



# First way to get computer name:
# $(Get-ADComputer -Properties * -Filter * | Where-Object {$_.IPv4Address -eq $ServersData_Json[$key].Ipv4Address} | Select-Object Name).Name

# Second way to get computer name, but slower:
# $(Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ServersData_Json.FirstServer.Ipv4Address).Name
foreach ($key in $ServersData_Json.Keys.Clone())
{
    $ServersData_Json[$key].Add(                                                        `
        "Name",                                                                         `
        $(                                                                              `
            Get-ADComputer                                                              `
            -Properties * -Filter * |                                                   `
            Where-Object {$_.IPv4Address -eq $($ServersData_Json[$key].Ipv4Address)} |  `
            Select-Object Name                                                          `
        ).Name                                                                          `
    )

    $ServersData_Json[$key].Add(                                                        `
        "DomainName",                                                                   `
        $(                                                                              `
            Get-ADDomainController -Filter * |                                          `
            Where-Object {$_.IPv4Address -eq $($ServersData_Json[$key].Ipv4Address)} |  `
            Select-Object HostName                                                      `
        ).HostName                                                                      `
    )


    PrintNewLine
    PrintCheck "Connecting to the computer $($ServersData_Json[$key].Name)..."
    if (!(Test-NetConnection -ComputerName $($ServersData_Json[$key].Name) -InformationLevel Quiet))
    {
        PrintFatal "Connection failed: computer is ofline or data is incorrect."
        break;
    }
    PrintOperationSuccess "Connection success!"


    PrintNewLine
    PrintCheck "Check for role DHCP..."
    $isDHCPInstalled = $Null
    try {
        $isDHCPInstalled = Get-WindowsFeature -ComputerName $($ServersData_Json[$key].Name) -Name DHCP
    }
    catch {
        PrintFatal "Unknown error. DHCP not founded."
    }

    if ($($isDHCPInstalled).InstallState -ne "Installed")
    {
        PrintNewLine
        PrintWarning "Role DHCP isn't installed on $($ServersData_Json[$key].Name)."

        PrintNewLine
        PrintOperationBegin "Adding DHCP role..."
        Install-WindowsFeature DHCP                     `
         -IncludeAllSubFeature                          `
         -IncludeManagementTools                        `
         -ComputerName $ServersData_Json[$key].Name     `
         -Credential Ad-training\Администратор          `
         -Confirm

        PrintNewLine
        PrintOperationBegin "Autorization DHCP server..."
        Add-DhcpServerInDC                                  `
        -DnsName $($ServersData_Json[$key].DomainName)      `
        -IPAddress $($ServersData_Json[$key].Ipv4Address)
        PrintOperationSuccess "DHCP server has been autorized."

        PrintNewLine
        PrintOperationBegin "Creating server local security group..."
        Add-DhcpServerSecurityGroup
        PrintOperationSuccess "Server security group has been created."

        PrintNewLine
        PrintOperationBegin "Supressing server manager..."
        # HKLM - HKey Lokal Machine
        Set-ItemProperty                                        `
        -Path HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12   `
        -Name ConfigurationState                                `
        -Value 2
        PrintOperationSuccess "Server manager has been supressed."

        PrintNewLine
        PrintOperationBegin "Setting additional setting for auto updates and cleaning..."
        Set-DhcpServerv4DnsSetting                          `
        -ComputerName $($ServersData_Json[$key].DomainName) `
        -DynamicUpdates Always                              `
        -DeleteDnsRROnLeaseExpiry $True
        PrintOperationSuccess "Automatical updates and cleaning has been setted."

        PrintNewLine
        PrintOperationBegin "Restarting DHCP service."
        Restart-Service -Name DHCPServer -Force
        PrintOperationSuccess "DHCP service has been restarted."

        PrintNewLine
        PrintOperationSuccess "DHCP role has been installed on $($ServersData_Json[$key].Name)."
        PrintNewLine
    }
    else {
        PrintNewLine
        PrintWarning "DHCP role is already installed."
    }

    if ($($ServersData_Json[$key].Ipv4Address) -eq $ServersData_Json.FirstServer.Ipv4Address)
    {
        PrintNewLine
        PrintInfo "Selected the main server.`nNew scope will be created and configured."

        PrintNewLine
        PrintCheck "Cheking for existence of the scope..."
        $isScopeExist = $Null
        try {
            $isScopeExist =                                     `
            Get-DhcpServerv4Scope                               `
            -ComputerName $ServersData_Json.FirstServer.Name    `
            -ScopeId $ScopeData_Json.CommonInfo.ScopeID
        }
        catch {
            PrintNewLine
            PrintInfo "The scope is already exist."
            continue
        }


        if ($Null -eq $isScopeExist -or `
        $isScopeExist.ScopeId.IPAddressToString -ne $ScopeData_Json.CommonInfo.ScopeID)
        {
            PrintNewLine
            PrintOperationBegin "Creating scope..."
            Add-DhcpServerv4Scope                                     `
            -Name $ScopeData_Json.CommonInfo.Name                     `
            -ComputerName $ServersData_Json.FirstServer.DomainName    `
            -StartRange $ScopeData_Json.RangeInfo.StartRange          `
            -EndRange $ScopeData_Json.RangeInfo.EndRange              `
            -SubnetMask $ScopeData_Json.RangeInfo.SubnetMask          `
            -LeaseDuration $ScopeData_Json.CommonInfo.LeaseDuration   `
            -Description $ScopeData_Json.CommonInfo.Description       `
            -State $ScopeData_Json.CommonInfo.State

            PrintOperationSuccess "Base scope has been created."


            PrintNewLine
            PrintOperationBegin "Setting addresses..."
            Set-DhcpServerv4OptionValue                              `
            -ScopeId $ScopeData_Json.CommonInfo.ScopeID              `
            -DnsDomain  $(                                                                  `
                Get-ADDomainController -Filter * |                                          `
                Where-Object {$_.IPv4Address -eq $ServersData_Json.FirstServer.Ipv4Address}|`
                Select-Object Domain                                                        `
            ).Domain                                                 `
            -DnsServer $ScopeData_Json.ServersInfo.DnsAddress        `
            -Router $ScopeData_Json.ServersInfo.RouterAddress
            PrintOperationSuccess "Environment addresses has been configured."


            PrintNewLine
            PrintOperationBegin "Adding exclusions..."
            Add-DhcpServerv4ExclusionRange                       `
            -ScopeId $ScopeData_Json.CommonInfo.ScopeID          `
            -StartRange $ScopeData_Json.ExclusionInfo.StartRange `
            -EndRange $ScopeData_Json.ExclusionInfo.EndRange
            PrintOperationSuccess "Exclusion range has been added to scope."


            PrintNewLine
            PrintOperationBegin "Adding reservation for MAC address 00-01-02-03-04-05..."
            Add-DhcpServerv4Reservation                                   `
            -ScopeId $ScopeData_Json.CommonInfo.ScopeID                   `
            -IPAddress $ScopeData_Json.ReservationInfo.ReservedIPAdress   `
            -ClientId $ScopeData_Json.ReservationInfo.MACAdress           `
            -Description $ScopeData_Json.ReservationInfo.Description
            PrintOperationSuccess "Reservation has been added."


            
            PrintNewLine
            PrintOperationBegin "Configuring policy..."
            PrintOperationBegin "Creating policy and setting conditions..."
            Add-DhcpServerv4Policy                                            `
            -Name $ScopeData_Json.PolicyInfo.Name                             `
            -ComputerName $ServersData_Json.FirstServer.DomainName            `
            -ScopeId $ScopeData_Json.CommonInfo.ScopeID                       `
            -Description $ScopeData_Json.PolicyInfo.Description               `
            -LeaseDuration $ScopeData_Json.CommonInfo.LeaseDuration           `
            -Condition $ScopeData_Json.PolicyInfo.Condition                   `
            -MacAddress $($ScopeData_Json.PolicyInfo.MacAdresses.EQ) , "$($ScopeData_Json.PolicyInfo.MacAdresses.AA_01_02_any)"
            PrintOperationSuccess "Scope level policy has been created."
            PrintOperationSuccess "Policy conditions has been setted."

            PrintNewLine
            PrintOperationBegin "Setting IP range for policy..."
            Add-DhcpServerv4PolicyIPRange                           `
            -ComputerName $ServersData_Json.FirstServer.DomainName  `
            -Name $ScopeData_Json.PolicyInfo.Name                   `
            -ScopeId $ScopeData_Json.CommonInfo.ScopeID             `
            -StartRange $ScopeData_Json.PolicyInfo.StartRange       `
            -EndRange $ScopeData_Json.PolicyInfo.EndRange
            PrintOperationSuccess "IP range for policy has been setted."

            PrintNewLine
            PrintOperationBegin "Setting router configuration for policy..."
            Set-DhcpServerv4OptionValue                                         `
            -ComputerName $ServersData_Json.FirstServer.DomainName              `
            -PolicyName $ScopeData_Json.PolicyInfo.Name                         `
            -ScopeId $ScopeData_Json.CommonInfo.ScopeID                         `
            -OptionId $ScopeData_Json.PolicyInfo.FeatureInfo.Router.OptionID    `
            -Value $ScopeData_Json.PolicyInfo.FeatureInfo.Router.Address 
            PrintOperationSuccess "Router configuration has been setted for policy."



            PrintNewLine
            PrintOperationBegin "Activating the scope..."
            Set-DhcpServerv4Scope -ScopeId $ScopeData_Json.CommonInfo.ScopeID -State Active
            PrintOperationSuccess "Scope has been activated."

            PrintNewLine
            PrintOperationSuccess "The scope has been created and configured."
            PrintNewLine
        }
        else
        {
            PrintNewLine
            PrintWarning "The scope is already exist."
            continue
        }
    }
    else
    {
        PrintNewLine
        PrintInfo "Selected reserve DHCP server.`nDHCP failover (active-passive) will be created and configured."
        
        PrintCheck "Check for DHCP failover existing..."
        $isFailoverExist = $Null
        try 
        {
            $isFailoverExist = Get-DhcpServerv4Failover                                                                    `
            -ComputerName $($ServersData_Json[$key].DomainName)                                         `
            -Name "$($ServersData_Json.FirstServer.DomainName)_$($ServersData_Json[$key].DomainName)"
        }
        catch
        {
            PrintWarning "Failover will be created on $($ServersData_Json[$key].DomainName)."
        }

        if ($Null -eq $isFailoverExist)
        {   
            PrintNewLine
            PrintOperationBegin "Failover is not exist.`nCreating failover ($($ServersData_Json.FirstServer.Name)_$($ServersData_Json[$key].Name)) relationship with the main server..."
            Add-DhcpServerv4Failover                                                                  `
            -Name "$($ServersData_Json.FirstServer.DomainName)_$($ServersData_Json[$key].DomainName)" `
            -PartnerServer $($ServersData_Json[$key].DomainName)                                      `
            -ScopeId $ScopeData_Json.CommonInfo.ScopeID                                               `
            -ComputerName $ServersData_Json.FirstServer.DomainName                                    `
            -MaxClientLeadTime $ScopeData_Json.FailoverInfo.MaxClientLeadTime                         `
            -StateSwitchInterval $ScopeData_Json.FailoverInfo.StateSwitchInterval                     `
            -AutoStateTransition $ScopeData_Json.FailoverInfo.AutoStateTransition                     `
            -ReservePercent $ScopeData_Json.FailoverInfo.ReservePercent                               `
            -SharedSecret $ScopeData_Json.FailoverInfo.SharedSecret                                   `
            -Force
            PrintOperationSuccess "Failover $($ServersData_Json.FirstServer.Name)_$($ServersData_Json[$key].Name) has been created."
            PrintNewLine
        }
        else
        {
            PrintNewLine
            PrintWarning "Failover for this scope is already exist on $($ServersData_Json[$key].DomainName)."
        }
    }

    PrintNewLine
    PrintOperationBegin "Final restarting DHCP service on $($ServersData_Json[$key].DomainName)."
    Restart-Service -Name DHCPServer -Force
    PrintOperationSuccess "DHCP service has been restarted and ready."
}





















