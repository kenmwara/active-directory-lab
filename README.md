<!-- banner --><a href="https://github.com/kenmwara"><img src="https://raw.githubusercontent.com/kenmwara/kenmwara/main/assets/brand/card-ad-lab.png?v=da29b5c6" width="100%" alt="Active Directory Lab: A Windows Server 2025 domain controller and a domain-joined Windows 11 client on Hyper-V, with five Group Policies proven on the client. 999 users in the domain."></a>

# Active Directory Lab: Domain Build and Group Policy Hardening

**On-premises Active Directory environment built on Hyper-V: a Windows Server 2025 domain controller, a domain-joined
Windows 11 client, 999 users in a departmental OU structure, and five Group Policies, each verified on the client.**

A two-VM domain was built on an isolated Hyper-V network to model a small organisation's identity infrastructure.
DC01 provides AD DS, DNS, DHCP and NAT; CLIENT01 reaches the network and the internet only through DC01. Users were
provisioned with PowerShell into IT, Finance and HR OUs with a security group per department, and an administrative
account was kept separate in `_ADMINS`. Five Group Policies enforce password and lockout rules, local-administrator
password rotation (Windows LAPS), removable-storage blocking, a department-scoped network drive, and logon auditing.
Each policy was applied and verified on the target system.

<img src="images/flow.png" width="100%" alt="Flow diagram in five steps. 1: CLIENT01 (Windows 11) joins an isolated private lab network with no direct internet. 2: DC01 provides an address by DHCP, names by DNS, and internet access only through its NAT. 3: a user signs in, authenticated by Active Directory on DC01 (Windows Server 2025, 999 users). 4: Group Policy applies five GPOs: password and lockout, LAPS, USB block, Finance drive, logon auditing. 5: every logon is audited; DC01's Security log records 4624 and 4625. Guards: isolation, the client reaches the world only through the DC; least privilege, the admin account is kept apart and the Finance drive is scoped to Finance only; verification, each policy proven on the client with gpresult and screenshots.">

**Status:** complete (built 16 to 18 October 2026). Build guide: [BUILD.md](BUILD.md).

## Group Policy results

| GPO | Scope | Control | Verification |
|---|---|---|---|
| Password and account lockout (Default Domain Policy) | Domain | 14-character complex passwords, 24 remembered; 5 failed attempts lock the account for 15 minutes | `Search-ADAccount -LockedOut` returns the test account: [13](screenshots/13-lockout-policy.png), [13b](screenshots/13b-password-policy.png), [14](screenshots/14-account-locked.png), [14a](screenshots/14a-client-throttle.png) |
| Windows LAPS | `Workstations` | Rotates CLIENT01's local Administrator password and stores it in AD, readable only by Domain Admins | `Get-LapsADPassword CLIENT01` shows a current rotation (value masked): [15](screenshots/15-laps-password.png) |
| Removable storage block | `Workstations` | Denies all access to all removable storage classes | `Deny_All = 1` under `RemovableStorageDevices` on CLIENT01: [16](screenshots/16-usb-block.png) |
| Finance drive map | `_USERS`, security-filtered to Finance | Maps `\\DC01\Finance` as `F:` | Finance user receives `F:`; HR user does not; `gpresult` reports *Denied (Security)*: [17](screenshots/17-finance-gets-F.png), [18](screenshots/18-hr-no-F.png), [20](screenshots/20-gpresult.png) |
| Logon auditing | `Domain Controllers` | Advanced Audit Policy: Logon, success and failure | Event IDs 4624 and 4625 in DC01's Security log: [19](screenshots/19-logon-audit-4624-4625.png) |

<p>
  <img src="images/readme-hero.png" width="720" alt="The Group Policy Management console; a Finance user receives the F: drive and an HR user does not; gpresult for the HR user shows Finance Drive Map, Filtering: Denied (Security)">
</p>

*Department-scoped drive mapping: the policy, the result for each department, and the `gpresult` evidence.*

## Environment and scope

- **Host:** Windows 10 Pro, Hyper-V, two virtual machines on a private switch (LabNet) plus a NAT uplink on DC01 only.
- **DC01:** Windows Server 2025. Forest `ad.kenmwara.com` (NetBIOS `KENLAB`, Windows2025Domain functional level);
  AD DS, DNS, DHCP (scope 172.16.0.100 to 200), Routing and Remote Access (NAT).
- **CLIENT01:** Windows 11 Enterprise, Generation 2 VM with virtual TPM, domain-joined, in the `Workstations` OU.
- **Directory:** 999 users (1,003 accounts including built-ins and the administrative account), OUs `_USERS\IT`,
  `_USERS\Finance`, `_USERS\HR`, one security group per department, administrative account in `_ADMINS`.
- **Out of scope:** production systems; all accounts exist only on the isolated lab network.

<img src="images/architecture.png" width="100%" alt="Detailed network diagram. One laptop running Windows 10 Pro and Hyper-V with two virtual switches. DC01 has NIC 1 on the Default Switch (the only route out of the lab) and NIC 2 at 172.16.0.1/24 on the LabNet private switch; it runs AD DS and DNS for ad.kenmwara.com, DHCP for 172.16.0.100 to 200, and NAT. CLIENT01 has one NIC on LabNet and receives its address, DNS and internet access through DC01. LabNet admits only the two VMs. The five Group Policies are listed with their verification.">

## Build milestones

| # | Milestone | Evidence |
|---|---|---|
| 1 | LabNet switch and both VMs created by [`scripts/create-lab-vms.ps1`](scripts/create-lab-vms.ps1) | [01](screenshots/01-host-vms-created.png) |
| 2 | DC01 renamed, network adapters named, static lab address assigned | [02](screenshots/02-dc01-renamed-checkpoint.png) |
| 3 | AD DS installed; forest `ad.kenmwara.com` (`KENLAB`) created | [03](screenshots/03-domain-created.png) |
| 4 | Dedicated Domain Admin account `a-kkariuki` created in `_ADMINS` | [04](screenshots/04-admin-account-created.png) |
| 5 | DHCP authorised; scope 172.16.0.100 to 200 active | [05](screenshots/05-dhcp-scope-active.png) |
| 6 | 999 users provisioned by script | [06](screenshots/06-users-created-1003.png), [09d](screenshots/09d-user-count.png) |
| 7 | Routing and Remote Access configured as NAT | [07](screenshots/07-nat-running.png) |
| 8 | CLIENT01 leased 172.16.0.100 from DC01 | [08](screenshots/08-client01-dhcp-address.png) |
| 9 | CLIENT01 joined to the domain; domain sign-in authenticated by DC01 | [09](screenshots/09-client01-joined-domain.png), [09b](screenshots/09b-domain-logon.png) |
| 10 | CLIENT01 internet access routed through DC01 (first hop 172.16.0.1) | [09c](screenshots/09c-nat-internet.png) |
| 11 | Department OUs and security groups created; CLIENT01 moved to `Workstations` | [10](screenshots/10-ou-structure.png), [11](screenshots/11-client01-in-workstations.png) |
| 12 | Five Group Policies created and linked | [12](screenshots/12-gpmc-overview.png) |

## Issues identified and resolved

| Issue | Root cause | Resolution |
|---|---|---|
| Finance drive map not applied to Finance users, with no error reported (`gpresult` showed the GPO applied; group membership was present in the token) | Item-level targeting inside the drive-map preference failed silently | Targeting removed; GPO scoped by Security Filtering to Finance, and Authenticated Users granted Read (not Apply), required since MS16-072 because user policy is retrieved with the computer account. Verified: Finance receives `F:`, HR shows *Denied (Security)* |
| `Update-LapsADSchema` failed with "insufficient access rights" | Schema extension requires Schema Admins, not Domain Admins; group membership is fixed at sign-in | Administrative account added to Schema Admins, then signed out and in to refresh the token |
| Domain users denied sign-in through Hyper-V Enhanced Session | Enhanced Session is a Remote Desktop sign-in | `KENLAB\Domain Users` added to CLIENT01's local Remote Desktop Users group |
| Clients intermittently located the domain controller on the wrong network | DC01's internet-facing adapter registered in the domain's DNS | `Set-DnsClient -RegisterThisConnectionsAddress $false` on that adapter |
| VM failed to boot from installation media | The "Press any key to boot from CD" prompt times out in about 5 seconds | VM reset and the prompt answered immediately |

## Related work: AI helpdesk agent

The lab hosts an AI helpdesk agent: Claude Code on CLIENT01, signed in as its own domain account
(`KENLAB\ai-operator`), restricted to seven AD tools over MCP, contained by AD delegation, a human approval gate and
DC01's audit log. Its design, 13-test security assessment and findings are documented separately in
**[Securing an AI Agent in Active Directory](https://github.com/kenmwara/securing-ai-agents-ad)**.

## Repository contents

| Item | Description |
|---|---|
| [BUILD.md](BUILD.md) | Step-by-step build with commands and a troubleshooting table |
| [`scripts/create-lab-vms.ps1`](scripts/create-lab-vms.ps1) | Creates the Hyper-V switch and both VMs |
| [`screenshots/`](screenshots/) | Evidence for every milestone and policy |
| [`images/`](images/) | Flow, architecture and composite images |

**Third-party components:** user provisioning used the public script
[joshmadakor1/AD_PS](https://github.com/joshmadakor1/AD_PS) (not copied here). The base topology adapts a public home-lab
design (VirtualBox, Windows Server 2019, Windows 10) to Hyper-V, Windows Server 2025 and Windows 11, with the
departmental structure and the five Group Policies added.

*Lab environment only. All accounts and credentials exist on an isolated network on a single host.*
