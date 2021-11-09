# Function to list the Ethernet Nics
function List-Nics
{
    param (
        [string]$Title = 'Menu Title'
    )
    Clear-Host
    Write-Host "--------------------$Title--------------------"

    Get-NetAdapter -physical | ?{$_.Name -like 'Ethernet*'} 
}

# Function to convert subnet mask to bits
function Convert-MaskToBits([string] $dottedIpAddressString)
{
  $result = 0; 
  # ensure we have a valid IP address
  [IPAddress] $ip = $dottedIpAddressString;
  $octets = $ip.IPAddressToString.Split('.');
  foreach($octet in $octets)
  {
    while(0 -ne $octet) 
    {
      $octet = ($octet -shl 1) -band [byte]::MaxValue
      $result++; 
    }
  }
  return $result;
}

# List the Nics we can operate on
List-Nics -Title 'List of Ethernet Nics'

# Blank line
Write-Host ""

# Set $selection based on the InterfaceIndex of the NIC we want to change
$selection = Read-Host "Enter the ifIndex of the NIC you want to set the IP static on"

# Set $adapter so we can operate on it
$adapter = Get-NetAdapter | ? {$_.InterfaceIndex -eq $selection}

# Ask for the new IP
$newip = Read-Host -Prompt "What will the new static IP address be?"

# Ask for the subnet and convert to bits
$maskbits = Convert-MaskToBits(Read-Host -Prompt 'What will the subnet mask be?')

# Ask for the default gateway
$newgw = Read-Host -Prompt "What do you want the Gateway to be?"

# Ask for the DNS server
$defaultDNS = '4.4.4.4'
$newDNS = Read-Host "Press enter to accept the default DNS server [$($defaultDNS)] or Enter a new one"
$newDNS = ($defaultDNS,$newDNS)[[bool]$newDNS]

#Blank line
Write-Host ""

# Show the IP we will use
Write-Host "IP Address:" $newip

# Show the mask length we will use
Write-Host "Mask Length:" $maskbits

# Show the default gateway we will use
Write-Host "Default Gateway:" $newgw

# Show the DNS server we will use
Write-Host "DNS server" $newDNS

# Remove any existing IP, gateway from our ipv4 adapter
If (($adapter | Get-NetIPConfiguration).IPv4Address.IPAddress) {
 $adapter | Remove-NetIPAddress -AddressFamily IPv4 -Confirm:$false
}
If (($adapter | Get-NetIPConfiguration).Ipv4DefaultGateway) {
 $adapter | Remove-NetRoute -AddressFamily IPv4 -Confirm:$false
}

# Disable DHCP if it's enabled
Set-ItemProperty -Path “HKLM:\SYSTEM\CurrentControlSet\services\Tcpip\Parameters\Interfaces\$((Get-NetAdapter -InterfaceIndex $selection).InterfaceGuid)” -Name EnableDHCP -Value 0
$interface = $adapter | Get-NetIPInterface -AddressFamily IPv4
If ($interface.Dhcp -eq "Enabled") {
$interface | Set-NetIPInterface -Dhcp Disabled
}

# Set the adapter
$adapter | New-NetIPAddress -AddressFamily IPv4 -IPAddress $newip -PrefixLength $maskbits -DefaultGateway $newgw | Out-Null

# Set the adapter DNS client server address
$adapter | Set-DnsClientServerAddress -ServerAddresses $newDNS 

# Wait for reset to DHCP
Write-Host ""
Read-Host -Prompt "Press Enter to reset the NIC to DHCP"

# Reset adapter to DHCP
Set-ItemProperty -Path “HKLM:\SYSTEM\CurrentControlSet\services\Tcpip\Parameters\Interfaces\$((Get-NetAdapter -InterfaceIndex $selection).InterfaceGuid)” -Name EnableDHCP -Value 1
$interface = $adapter | Get-NetIPInterface -AddressFamily IPv4
If ($interface.Dhcp -eq "Disabled") {
$interface | Set-NetIPInterface -Dhcp Enabled
}
If (($interface | Get-NetIPConfiguration).Ipv4DefaultGateway) {
 $interface | Remove-NetRoute -Confirm:$false
 }
$interface | Set-DnsClientServerAddress -ResetServerAddresses