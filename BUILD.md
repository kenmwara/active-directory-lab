# Build guide: Active Directory on Hyper-V (Windows Server 2025 + Windows 11)

The build steps and the commands used. Every value below is the one this lab uses; pick your own, but stay
consistent.

| Item | Value |
|---|---|
| Domain | `ad.kenmwara.com` (Microsoft's advice: a subdomain of a domain you own), NetBIOS name `KENLAB` |
| DC LabNet address | `172.16.0.1/24`, DNS `127.0.0.1` |
| DHCP scope | `172.16.0.100`–`172.16.0.200`, router and DNS = `172.16.0.1` |
| Admin account | `a-kkariuki` in OU `_ADMINS`, member of Domain Admins |
| Lab password | one lab-only password for everything; never one you use anywhere real |

**Why Hyper-V and not VirtualBox:** with Windows' memory integrity (virtualisation-based security) on, VirtualBox drops
into a slow compatibility mode. Hyper-V is built into Windows 10/11 Pro, runs at full speed beside it, and gives Windows
11 the virtual TPM and Secure Boot it insists on.

**You need:** about 60 GB free (DC01 grows to ~20–25 GB, CLIENT01 to ~25 GB, plus two ISOs), 16 GB of RAM, and the free
evaluation ISOs for **Windows Server 2025** and **Windows 11 Enterprise** from the Microsoft Evaluation Center.

**Take a Hyper-V checkpoint after every numbered step** (right-click the VM → Checkpoint), so a mistake is a rollback,
not a rebuild. Keep two or three; old checkpoints eat disk.

---

## 1. Turn on Hyper-V

*Turn Windows features on or off* → tick **Hyper-V** → restart. Or, in an administrator PowerShell:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```

## 2–3. The lab network and both VMs

[`scripts/create-lab-vms.ps1`](scripts/create-lab-vms.ps1) does steps 2 and 3 plus CLIENT01's shell in one go (it finds
both ISOs in Downloads and is safe to re-run). By hand:

```powershell
New-VMSwitch -Name "LabNet" -SwitchType Private

$vmPath = "C:\HyperV"
New-VM -Name DC01 -Generation 2 -MemoryStartupBytes 4GB -Path $vmPath `
       -NewVHDPath "$vmPath\DC01\DC01.vhdx" -NewVHDSizeBytes 60GB -SwitchName "Default Switch"
Set-VMMemory DC01 -DynamicMemoryEnabled $true -MinimumBytes 2GB -MaximumBytes 4GB
Set-VMProcessor DC01 -Count 2
Add-VMNetworkAdapter -VMName DC01 -SwitchName "LabNet"
Add-VMDvdDrive -VMName DC01 -Path "$env:USERPROFILE\Downloads\<server-2025-eval>.iso"
Set-VMFirmware DC01 -FirstBootDevice (Get-VMDvdDrive DC01)
```

Start DC01, press a key at *Press any key to boot from CD*, and install **Windows Server 2025 Standard Evaluation
(Desktop Experience)**. Without Desktop Experience there is no GUI.

## 4. Network cards, static address, server name

On DC01, in an administrator PowerShell:

```powershell
Get-NetAdapter                      # the LabNet card shows 169.254.x.x; the other has a real address
Rename-NetAdapter -Name "Ethernet"   -NewName "INTERNET"
Rename-NetAdapter -Name "Ethernet 2" -NewName "LABNET"
New-NetIPAddress -InterfaceAlias "LABNET" -IPAddress 172.16.0.1 -PrefixLength 24
Set-DnsClientServerAddress -InterfaceAlias "LABNET" -ServerAddresses 127.0.0.1
Rename-Computer -NewName DC01 -Restart
```

No gateway on LABNET: DC01 *is* the gateway. If the INTERNET card's automatic address happens to start `172.16.0.`, use
`10.10.0.x` for the lab instead.

## 5. Active Directory and the domain

```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Install-ADDSForest -DomainName "ad.kenmwara.com" -DomainNetbiosName "KENLAB" -InstallDns
```

After the restart, sign in as `KENLAB\Administrator` and keep the INTERNET card out of the domain's DNS:

```powershell
Set-DnsClient -InterfaceAlias "INTERNET" -RegisterThisConnectionsAddress $false
```

## 6. Your own admin account

Active Directory Users and Computers (`dsa.msc`) → New → Organizational Unit `_ADMINS` → New → User `a-kkariuki` →
Member Of → **Domain Admins**. Then sign out and use `KENLAB\a-kkariuki` from here on. Run admin tools from **Terminal
(Admin)**: UAC gives even a Domain Admin a filtered token until you elevate.

## 7. Routing and NAT

```powershell
Install-WindowsFeature RemoteAccess, Routing -IncludeManagementTools
```

Tools → **Routing and Remote Access** → right-click DC01 → *Configure and Enable* → **NAT** → choose the **INTERNET**
card as the public interface. If the interface list is empty, cancel and reopen the console.

## 8. DHCP

```powershell
Install-WindowsFeature DHCP -IncludeManagementTools
Add-DhcpServerInDC -DnsName "dc01.ad.kenmwara.com" -IPAddress 172.16.0.1
Add-DhcpServerSecurityGroup; Restart-Service DHCPServer
$s = @{ Name = "Lab"; StartRange = "172.16.0.100"; EndRange = "172.16.0.200" }
Add-DhcpServerv4Scope @s -SubnetMask 255.255.255.0
$o = @{ ScopeId = "172.16.0.0"; Router = "172.16.0.1"; DnsServer = "172.16.0.1" }
Set-DhcpServerv4OptionValue @o -DnsDomain ad.kenmwara.com
```

## 9. Users, then CLIENT01

**Users.** Download `1_CREATE_USERS.ps1` and `names.txt` from
[joshmadakor1/AD_PS](https://github.com/joshmadakor1/AD_PS) into one folder, read the script, set your own lab password
at the top, then:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\1_CREATE_USERS.ps1
(Get-ADUser -Filter *).Count        # 1,003 here: 999 users + Administrator, Guest, krbtgt and the admin
```

**CLIENT01** (already created by the script in step 2–3): install Windows 11 Enterprise, then on CLIENT01:

```powershell
ipconfig                                  # expect 172.16.0.1xx; 169.254.x.x means DHCP isn't reaching it
ping 172.16.0.1 ; nslookup ad.kenmwara.com ; ping google.com
Rename-Computer -NewName CLIENT01 -Restart
Add-Computer -DomainName "ad.kenmwara.com" -Credential "KENLAB\a-kkariuki" -Restart
```

Sign in as a generated user (`KENLAB\<username>`) and check who authenticated you:

```powershell
whoami ; $env:LOGONSERVER                 # kenlab\<user>, \\DC01
Test-NetConnection 1.1.1.1 -Port 443      # internet through DC01's NAT
tracert -d -h 2 1.1.1.1                   # first hop 172.16.0.1
```

## 10. Company structure and Group Policy

```powershell
$dom = "DC=ad,DC=kenmwara,DC=com"
New-ADOrganizationalUnit -Name "Workstations" -Path $dom
"IT","Finance","HR" | % { New-ADOrganizationalUnit -Name $_ -Path "OU=_USERS,$dom" }
New-ADOrganizationalUnit -Name "Groups" -Path $dom
"IT","Finance","HR" | % { New-ADGroup -Name $_ -GroupScope Global -GroupCategory Security -Path "OU=Groups,$dom" }
Move-ADObject (Get-ADComputer CLIENT01).DistinguishedName -TargetPath "OU=Workstations,$dom"
```

Then, in **Group Policy Management** (`gpmc.msc`), one GPO at a time, each proven on CLIENT01 with `gpupdate /force` and
`gpresult /r`:

| GPO | Where | Proof |
|---|---|---|
| Password + lockout | Default Domain Policy → Computer → Policies → Windows Settings → Security Settings → Account Policies | 5 wrong passwords lock the account; `Search-ADAccount -LockedOut` |
| Windows LAPS | On DC01: `Update-LapsADSchema` (needs **Schema Admins**; sign out and in after adding yourself) and `Set-LapsADComputerSelfPermission -Identity "OU=Workstations,$dom"`. GPO on Workstations: Computer → Admin Templates → System → LAPS → *Configure password backup directory* = Active Directory | `Get-LapsADPassword CLIENT01` (leave off `-AsPlainText` for any screenshot: it prints the password) |
| Block USB storage | Computer → Admin Templates → System → Removable Storage Access → *All Removable Storage classes: Deny all access* | `Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices` shows `Deny_All = 1` |
| Finance drive | A share on DC01 for the Finance group; GPO on `_USERS`: User → Preferences → Windows Settings → Drive Maps → `F:`. Scope it with **Security Filtering = Finance** and give **Authenticated Users Read** on the Delegation tab (not item-level targeting: see the README) | Finance user gets `F:`, HR user doesn't, HR's `gpresult` shows *Denied (Security)* |
| Logon auditing | GPO on Domain Controllers: Computer → Policies → Windows Settings → Security Settings → Advanced Audit Policy → Logon/Logoff → Logon = Success + Failure | Event Viewer on DC01: 4624 and 4625 |

## When it breaks

| Symptom | Likely cause |
|---|---|
| "This PC can't run Windows 11" | VM is Generation 1, the TPM isn't enabled, or Secure Boot is off |
| CLIENT01 shows 169.254.x.x | Its card isn't on LabNet, the scope isn't active, or DHCP isn't authorised |
| Can't join the domain | CLIENT01's DNS isn't 172.16.0.1, so it can't find the domain (`ipconfig /all`) |
| CLIENT01 has no internet | NAT isn't on the INTERNET card, or the DHCP router option is missing |
| "The boot loader failed" | The boot-from-CD prompt timed out. Reset the VM, click inside, tap Space |
| Long pasted commands break with `Missing closing ')'` | *Type clipboard text* splits long lines. Paste short lines (build values in variables) or use Enhanced Session |
| A `Read-Host` password prompt swallows the next command | Whatever arrives while it waits becomes the password. Type it by hand, or create accounts in `dsa.msc` |
| "You do not have adequate user rights" as the admin | UAC filtered token: open Terminal (Admin) |
| Domain user: "you need the right to sign in through Remote Desktop Services" | Enhanced Session is an RDP sign-in: `net localgroup "Remote Desktop Users" "KENLAB\Domain Users" /add` on CLIENT01 |
| `Update-LapsADSchema`: insufficient access rights | You need Schema Admins, and a fresh sign-in so the token carries it |
| Paste stops working after signing out of a VM | Enhanced Session's clipboard drops on sign-out: close the VM window and reconnect from Hyper-V Manager |
| Group Policy tabs *Scope* and *Delegation* are missing | They live in the Group Policy Management console (select the GPO), not in the editor |
