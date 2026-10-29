<!-- banner --><a href="https://github.com/kenmwara"><img src="https://raw.githubusercontent.com/kenmwara/kenmwara/main/assets/brand/card-ad-lab.png?v=c6af43f28f" width="100%" alt="Active Directory Lab: A Windows Server 2025 domain controller and a domain-joined Windows 11 client on Hyper-V, with five Group Policies proven on the client. 999 users in the domain."></a>

# Active Directory Lab: Domain Build and Group Policy Hardening

**A small company network, built from scratch on one laptop: a Windows server that manages 999 user accounts, a
Windows 11 work PC, and five company security rules, each tested on the PC.**

The lab copies how a small organisation runs its logins and computers. The server (DC01, Windows Server 2025) runs
Active Directory, which holds every user account and checks every login; it also gives the PC its network address and
is the PC's only way to the internet. Users were created in IT, Finance and HR departments, and the admin account was
kept separate. Five Group Policies (company-wide rules) enforce strong passwords and account lockout, rotate the local
admin password automatically (Windows LAPS), block USB storage, give only Finance staff a Finance drive, and record
every login. Each rule was checked on the PC, with screenshots as proof.

<img src="images/flow.png" width="100%" alt="How the lab works. Active Directory home lab · how it works A small company network, every rule tested 1A work PC joins the networkA Windows 11 PC on a private lab network, with no direct internet 2The server hands out the basicsThe main server gives it an address and name lookups, and is its only way to the internet 3A user signs inActive Directory checks the login (Windows Server 2025, 999 users) 4Company rules apply5 Group Policies: strong passwords and lockout, rotating admin passwords, USB sticks blocked, a Finance-only drive, login records 5Every login is recordedThe server logs each successful and failed sign-in IsolationThe PC can only reach the internet through the server Least privilegeAdmin account kept separate; only Finance sees the Finance drive VerificationEach rule checked on the PC, with screenshots as proof Built 16–18 Oct 2026 on one laptop: a server and a PC, 999 users, 3 departments, 5 Group Policies.github.com/kenmwara/active-directory-lab">

**Status:** complete (built 16 to 18 October 2026). Build guide: [BUILD.md](BUILD.md).

## The five company rules

<img src="images/rules.png" width="100%" alt="Five company rules, each tested on the work PC. Group Policies are rules the server pushes to every computer and user. Each one was switched on, then checked. Strong passwords: At least 14 characters, and the last 24 can't be reused. Five wrong tries lock the account for 15 minutes. Proof: A test account really did lock after five wrong tries. Rotating admin password: The PC's local admin password changes on its own and is stored safely on the server (Windows LAPS). Proof: The server shows a freshly rotated password, hidden in the screenshot. USB sticks blocked: No USB drives or other removable storage on work PCs. Proof: The PC's settings show the block switched on. Finance-only drive: Finance staff get the Finance drive. Nobody else does. Proof: A Finance user gets the drive; an HR user doesn't, and Windows' own report says why. Every login recorded: The server logs each successful and failed sign-in. Proof: Both kinds of sign-in show up in the server's security log. Screenshot: Only Finance staff get the Finance drive. HR doesn't, and Windows' own report shows why.">

<details><summary>The rules as a table, with links to every screenshot</summary>

| GPO | Scope | Control | Verification |
|---|---|---|---|
| Password and account lockout (Default Domain Policy) | Domain | 14-character complex passwords, 24 remembered; 5 failed attempts lock the account for 15 minutes | `Search-ADAccount -LockedOut` returns the test account: [13](screenshots/13-lockout-policy.png), [13b](screenshots/13b-password-policy.png), [14](screenshots/14-account-locked.png), [14a](screenshots/14a-client-throttle.png) |
| Windows LAPS | `Workstations` | Rotates CLIENT01's local Administrator password and stores it in AD, readable only by Domain Admins | `Get-LapsADPassword CLIENT01` shows a current rotation (value masked): [15](screenshots/15-laps-password.png) |
| Removable storage block | `Workstations` | Denies all access to all removable storage classes | `Deny_All = 1` under `RemovableStorageDevices` on CLIENT01: [16](screenshots/16-usb-block.png) |
| Finance drive map | `_USERS`, security-filtered to Finance | Maps `\\DC01\Finance` as `F:` | Finance user receives `F:`; HR user does not; `gpresult` reports *Denied (Security)*: [17](screenshots/17-finance-gets-F.png), [18](screenshots/18-hr-no-F.png), [20](screenshots/20-gpresult.png) |
| Logon auditing | `Domain Controllers` | Advanced Audit Policy: Logon, success and failure | Event IDs 4624 and 4625 in DC01's Security log: [19](screenshots/19-logon-audit-4624-4625.png) |

</details>

## The network in detail

- **Host:** Windows 10 Pro, Hyper-V, two virtual machines on a private switch (LabNet) plus a NAT uplink on DC01 only.
- **DC01:** Windows Server 2025. Forest `ad.kenmwara.com` (NetBIOS `KENLAB`, Windows2025Domain functional level);
  AD DS, DNS, DHCP (scope 172.16.0.100 to 200), Routing and Remote Access (NAT).
- **CLIENT01:** Windows 11 Enterprise, Generation 2 VM with virtual TPM, domain-joined, in the `Workstations` OU.
- **Directory:** 999 users (1,003 accounts including built-ins and the administrative account), OUs `_USERS\IT`,
  `_USERS\Finance`, `_USERS\HR`, one security group per department, administrative account in `_ADMINS`.
- **Out of scope:** production systems; all accounts exist only on the isolated lab network.

<img src="images/architecture.png" width="100%" alt="The lab network: a small office network on one laptop, with one way in and out. Two virtual computers run on one laptop: a server (DC01, Windows Server 2025) and a work PC (CLIENT01, Windows 11). The PC has no internet of its own, so everything it does goes through the server. The server runs Active Directory with 999 users in IT, Finance and HR, gives the PC its address and name lookups, and is the only way to the internet. The PC receives the five company rules, each checked with a screenshot, and later an AI IT helper tested in its own project. The five rules: strong passwords and lockout, a rotating admin password (Windows LAPS), USB sticks blocked, a Finance-only drive, and every login recorded.">

## How it was built

<img src="images/build.png" width="100%" alt="Built in three days, step by step. 16 to 18 October 2026. Every step has a screenshot as proof (listed below the diagram). Phase 1, Set up the machines: Created the private network and both virtual computers with one script; Named the server and gave it a fixed address. Phase 2, Build the directory: Turned the server into a domain controller for ad.kenmwara.com; Created a separate admin account; Switched on automatic network addresses; Added 999 users with a script. Phase 3, Connect the work PC: Shared the server's internet connection with the lab; The PC got its address from the server; The PC joined the company network and a user signed in; Checked the PC's internet runs through the server. Phase 4, Organise and apply rules: Created the IT, Finance and HR departments and groups; moved the PC into Workstations; Created and switched on the five company rules.">

<details><summary>Every step, with its screenshot</summary>

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

## Problems found and fixed

<img src="images/issues.png" width="100%" alt="Five problems hit during the build, and how each was fixed. Problem: The Finance drive didn't appear for Finance staff, and no error said why. Why: A targeting setting inside the rule was failing silently. Fix: Removed it and limited the whole rule to the Finance group, with one read permission Windows needs. Finance gets the drive; HR is refused. Problem: Installing the rotating admin password feature (LAPS) failed: 'insufficient access rights'. Why: That change needs Schema Admins rights, a level above Domain Admins, and new rights only count after signing in again. Fix: Added the admin to Schema Admins, then signed out and back in. Problem: Company users couldn't sign in through the laptop's window into the PC. Why: That window counts as a remote-desktop login. Fix: Allowed company users to use remote desktop on the PC. Problem: The PC sometimes looked for the server on the wrong network. Why: The server published its internet-side address in the company directory too. Fix: Told that connection not to publish its address. Problem: A virtual computer wouldn't start from the install disk. Why: The 'press any key' prompt gives up after about 5 seconds. Fix: Restarted it and pressed a key straight away.">

<details><summary>The problems as a table, with the technical detail</summary>

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

</details>

</details>

**Third-party components:** user provisioning used the public script
[joshmadakor1/AD_PS](https://github.com/joshmadakor1/AD_PS) (not copied here). The base topology adapts a public home-lab
design (VirtualBox, Windows Server 2019, Windows 10) to Hyper-V, Windows Server 2025 and Windows 11, with the
departmental structure and the five Group Policies added.

*Lab environment only. All accounts and credentials exist on an isolated network on a single host.*
