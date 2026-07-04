# Backport Instructions: MauleTech/PWSH → ATG-PS-Functions

This is a working document for completing the backport of bug fixes and functionality
improvements from the MauleTech fork (https://github.com/MauleTech/PWSH) into this repo.
It is written so that any model or engineer can execute one work item at a time with no
other context. Delete this file before merging to master, or keep it as a tracking doc.

## Context

- This repo (Ambitions) deploys to **`C:\Ambitions`** on client machines. Functions are
  plain-text function collections in `Functions/ATG-PS-<Verb>.txt`, loaded at runtime via
  `irm ps.acgs.io | iex`, which fetches each file from
  `https://raw.githubusercontent.com/AmbitionsTechnologyGroup/ATG-PS-Functions/master/Functions/...`
  (see `Functions/URL-List.csv`).
- The fork (MauleTech) generalized the same code for other MSPs. It deploys to **`C:\IT`**
  via a `$ITFolder` variable, uses `.psm1` modules in `Functions/PS-<Verb>.psm1`, and loads
  via `raw.githubusercontent.com/MauleTech/PWSH/refs/heads/main/LoadFunctions.txt`.
- The fork is ahead on bug fixes. We are pulling FIXES back, NOT the rebranding.

## Setup

```bash
git clone https://github.com/MauleTech/PWSH /tmp/PWSH
```

All "fork" line references below are against that clone's `Functions/` directory. Line
numbers are approximate; locate functions by name (`grep -n "Function <Name>"`).

## Hard rules (apply to every work item)

1. **Never break `C:\Ambitions`.** Keep every existing `C:\Ambitions` path. Never introduce
   `$ITFolder`, `C:\IT`, `MauleTech`, `mauletech.com`, `ps.mauletech.com`, or
   `MauleTech/PWSH` GitHub URLs into this repo's function files.
   Exception already made deliberately: Chocolatey package sources now point at
   `cache.mauletech.com` + `community.chocolatey.org` (the old `choco.ambitionsgroup.com`
   server is retired). Do not "fix" that back.
2. Keep loader lines exactly as they are: `irm ps.acgs.io | iex`,
   `iex(iwr ps.acgs.io -usebasicparsing)`, `Invoke-RestMethod ps.acgs.io | Invoke-Expression`.
3. **Known fork bug — do not copy:** several fork functions contain literal `'$ITFolder\...'`
   inside SINGLE quotes (the variable never expands there). When you see it, substitute the
   original's `C:\Ambitions` literal.
4. Do not copy `# SIG # Begin signature block` blocks or `Export-ModuleMember` lines.
   Target files are plain `.txt` function collections.
5. Match the target file's TAB indentation. If a fork function uses spaces, convert.
6. Where the fork calls `Invoke-ValidatedDownload` (a fork-only download-hash-validation
   helper), keep the original's plain `Invoke-WebRequest` / `WebClient` download unless the
   work item says otherwise.
7. Helpers you MAY call because they exist here or are part of this backport:
   `Get-FileDownload`, `Get-InstalledApplication`, `Start-PSWinGet`, `Enable-SSL`,
   `Install-Choco`, `Invoke-WinGetInstall` (added by item B5).
   Helpers you may NOT call (not backported): `Invoke-ValidatedDownload`,
   `Restart-ComputerSafely`, `Repair-ChocoDependency`, `Update-OEMDrivers`,
   `Get-DecryptedConfig`, `ConvertTo-EncodedCommand`.
8. No new external dependencies; PowerShell 5.1 compatible.

## Verification recipe (run after every item)

```bash
# 1. No branding leakage (must print nothing):
grep -n 'ITFolder\|mauletech\|MauleTech' Functions/<edited-file>

# 2. Brace/paren balance did not change vs the committed version.
#    Use the LINE-BASED checker below, not a multiline regex — multiline regex
#    substitution for quoted strings gets confused by PowerShell here-strings
#    (@' ... '@ / @" ... "@) that span many lines and produced false positives
#    during Batch D. This line-based version strips comments/strings per line
#    instead, which handles here-strings correctly in practice:
python3 - <<'EOF'
import re, subprocess
f = "Functions/<edited-file>"
def depth(text):
    d = 0
    for l in text.splitlines():
        l = re.sub(r"`.", "", l)
        l = re.sub(r"'[^']*'", "''", l)
        l = re.sub(r'"[^"]*"', '""', l)
        l = re.sub(r"#.*", "", l)
        d += l.count("{") - l.count("}")
    return d
new = depth(open(f, encoding="utf-8-sig").read())
old = depth(subprocess.run(["git", "show", f"HEAD:{f}"], capture_output=True, text=True).stdout)
print("old", old, "new", new, "DELTA", new - old)  # DELTA must be 0
EOF
```

If PowerShell is available, prefer a real parse:
`[System.Management.Automation.Language.Parser]::ParseFile("<file>", [ref]$null, [ref]$errors); $errors`

Commit after each work item with a message describing the function fixed and why.

## Already completed on branch `claude/ambitions-backport-updates-jqqtli` — do NOT redo

- `Scripts/Chocolatey/installchoco.txt` — full rewrite (MauleTech sources, winget → NuGet →
  official script fallbacks); `Set-ChocolateySources` added to `ATG-PS-Set.txt`;
  `Install-Choco` double-invocation fixed; `UpdateWindows.txt` choco URL repointed.
- `ATG-PS-Get.txt`: `Get-FileDownload` rewrite, `Get-InstalledApplication` rewrite
  (no more Win32_Product), `Get-InternetHealth` speedtest 1.2.0.
- `ATG-PS-Install.txt`: `Install-WinGet` swallowed `winget source update` fix;
  `Install-O365ProofPointConnectors` smart quotes → straight quotes and junk-filter loop
  now iterates `$DisableMailoxJunkFilters` (was `$All`, never assigned).
- `ATG-PS-Start.txt`: `Start-BackstageBrowser` 32-bit Pale Moon + corrupt-install self-repair.
- `ATG-PS-Convert.txt`: en-dashes → hyphens in `Convert-ToSharedMailbox`.
- `ATG-PS-Set.txt`: `Set-DnsMadeEasyDDNS` http → https.
- **BATCH A complete** (A1-A7, A9): Update-Windows, Update-DellServer, Update-DellPackages,
  Update-PSWinGetPackages, Update-DnsServerRootHints, Update-ITS247Agent https,
  Update-PowerShellModule NuGet pin, Uninstall-Application rewrite.
  A8 (`*monthlty*` typo in Update-O365Apps) deliberately left for maintainer review —
  the same typo exists in the fork, and fixing it changes runtime behavior.
- **BATCH B complete** (B1-B5): Remove-PathForcefully, Remove-DuplicateFiles,
  Remove-StaleObjects targeted fixes, Invoke-IPv4NetworkScan three fixes,
  Invoke-WinGetInstall helper added (adoption in Install-NetExtender/Install-WinGetApps/
  Update-Edge still open).
- **BATCH C complete** (C1-C3): Connect-Wifi rewrite, Connect-O365AzureAD deprecation
  warnings, Enable-SSL TLS hardening.

Remaining open work: BATCH D (D1-D6), the decision-needed items, and optional new-function
cherry-picks below.

---

## BATCH A — `Functions/ATG-PS-Update.txt` and `Functions/ATG-PS-Uninstall.txt`

### A1. Update-Windows (P1 — dead CDN)
Fork source: `PS-Update.psm1`, function `Update-Windows` (~lines 1456-1544).
The original's manual PSWindowsUpdate fallback downloads
`https://psg-prod-eastus.azureedge.net/packages/pswindowsupdate.2.2.0.3.nupkg` — that CDN
(Edgio/azureedge) is retired; the URL is dead. Backport:
- New URL `https://cdn.powershellgallery.com/packages/pswindowsupdate.2.2.1.5.nupkg`,
  version references bumped 2.2.0.3 → 2.2.1.5.
- Add explicit `Import-Module PSWindowsUpdate` after module install.
- Wrap both `Get-WUInstall` passes in try/catch that runs `Reset-WUComponents` once and
  retries (fork lines ~1516-1538).
- Only install Chocolatey on the PS<5 legacy path; use NuGet provider bootstrap otherwise
  (fork ~1475-1481).
- Keep `C:\Ambitions` for the nupkg download folder (fork lines ~1503-1506 have the
  single-quoted `'$ITFolder'` bug — see hard rule 3).

### A2. Update-DellServer (P1 — reinstalls every run)
Fork source: `PS-Update.psm1`, function `Update-DellServer` (~lines 277-330).
Original downloads DSU 2.1.1.0, saves it as "Dell System Update 2.0.1.exe", pins an old
SHA256, and gates on `-NotLike "2.0.1.0*"` — internally inconsistent, so it re-downloads
and reinstalls on every run, and the old `dl.dell.com` FOLDER link is rotting. Backport the
fork's consistent DSU **2.2.0.1** triplet: download URL, filename, and version gate must all
agree. The fork replaced the manual hash check with `Invoke-ValidatedDownload` (not
available here): keep a plain download, drop the stale hash constant, and add a
file-exists / size > 0 sanity check with a comment `# TODO: re-pin SHA256 after verifying
the DSU 2.2.0.1 download on a trusted network`. Keep `C:\Ambitions` paths.

### A3. Update-DellPackages (P1 — perpetual uninstall/reinstall loop)
Fork source: `PS-Update.psm1`, function `Update-DellPackages` (~lines 117-276).
Backport these behaviors:
- Choose ONE `$InstallSource` ('winget' or 'choco') up front; use it for BOTH the
  version check and the install (original mixes sources, causing false "not current").
- Compare versions by casting to `[System.Version]` with `-lt` instead of string
  `-notmatch` (prevents false downgrades/reinstalls).
- Install the .NET 8 Desktop Runtime prerequisite before Dell Command Update:
  winget id `Microsoft.DotNet.DesktopRuntime.8`, choco id `dotnet-8.0-desktopruntime`.
- Gate the expensive `Uninstall-Application` calls behind one `Get-InstalledApplication`
  scan (that function is already backported).
- SYSTEM-context path: when running as SYSTEM (winget.exe unavailable), route through
  `Start-PSWinGet` (exists in `ATG-PS-Start.txt`) after
  `Update-PowerShellModule -ModuleName Microsoft.WinGet.Client`.
- Take the fork's DCU configure flags: `-advancedDriverRestore=enable -scheduleAuto
  -updatesNotification=disable` and `/applyUpdates -forceupdate=enable`.

### A4. Update-PSWinGetPackages (P2 — verbatim)
Fork source: `PS-Update.psm1` (~lines 1382-1388). When `winget.exe` is on PATH, run
`winget update --all --silent --accept-package-agreements --accept-source-agreements
--source winget --include-unknown --force --disable-interactivity` directly; otherwise fall
back to the existing `Start-PSWinGet` path. Branding-free; copy faithfully.

### A5. Update-DnsServerRootHints (P2 — verbatim)
Fork source: `PS-Update.psm1` (~lines 334-459). Replaces blind remove-and-re-add of every
root hint with: parse using `RemoveEmptyEntries` + blank-line guard, correctly read current
hints' IPv4 addresses, print an up-to-date/needs-update/missing comparison table, and only
modify entries that differ. Branding-free; copy faithfully.

### A6. Update-ITS247Agent (P3 — one character)
Change `http://update.itsupport247.net/agtupdt/DPMAPatch.exe` to `https://`.
Keep everything else, including `C:\Ambitions` paths.

### A7. Update-PowerShellModule (P3)
Add `-MinimumVersion 2.8.5.201` to both `Install-PackageProvider -Name NuGet -Force`
call sites inside this function (original lines ~499 and ~554).

### A8. Update-O365Apps typo (shared bug, both repos)
Original line ~450 contains `*monthlty*` (typo) in the channel check, making the comparison
behave incorrectly. Read the surrounding logic FIRST: the string should match the actual
channel name being compared (`monthly`). If fixing the typo would invert the intended
behavior, leave it and flag it in your report instead.

### A9. Uninstall-Application (P2 — drop-in rewrite; EXE uninstalls are broken today)
Fork source: `PS-Uninstall.psm1` (~lines 1-293): `Uninstall-RegistryApp` +
`Invoke-UninstallString` + `Invoke-SilentExeUninstall` replace the original's
`Uninstall-MsiApp`, which shoves every registry `UninstallString` into
`msiexec /X ... /qn` (guaranteed failure for NSIS/Inno/InstallShield EXE uninstallers).
The fork prefers `QuietUninstallString`, extracts a proper `{GUID}` for msiexec with
`/qn /norestart` + exit-code capture, sniffs EXE uninstaller signatures to pick the right
silent switch, and verifies removal afterwards. Branding-free; replace original lines
~1-115 faithfully. Leave `Uninstall-UmbrellaDNS` untouched.

---

## BATCH B — `Functions/ATG-PS-Remove.txt` and `Functions/ATG-PS-Invoke.txt`

### B1. Remove-PathForcefully (P1 — verbatim)
Fork source: `PS-Remove.psm1`, locate `Function Remove-PathForcefully`. Fixes silent
failure on paths containing `[` `]` (wildcard interpretation): `-LiteralPath` everywhere,
`.ProviderPath` from `Resolve-Path`, bulk-delete fast path with per-item deepest-first
fallback, pipeline input (`ValueFromPipeline`, aliases `FullName`/`PSPath`, `process` block).
Branding-free; replace the whole original function.

### B2. Remove-DuplicateFiles (P1 — -Recurse is broken today)
Fork source: `PS-Remove.psm1` (~lines 165-297). Original's `-Recurse` branch calls the
inner helper with `-Path` but the helper declares no parameters (always throws), and its
directory enumeration ignores `$Path`. Fork fixes both and adds a preview/size summary +
`SupportsShouldProcess` confirmation. ADAPT: the fork's bootstrap line uses the MauleTech
LoadFunctions URL — keep the original's `Invoke-RestMethod ps.acgs.io | Invoke-Expression`.

### B3. Remove-StaleObjects (P2 — targeted fixes only)
Do NOT bring the fork's `-Schedule` feature (it hardcodes MauleTech infrastructure).
Only: (a) delete the stray debug line `Write-Host $VerbosePreference`; (b) change
`Remove-PathForcefully -Path $StubbornItem.PSPath` to `$StubbornItem.FullName`;
(c) add `-LiteralPath` and `-ErrorAction SilentlyContinue` to the `Get-ChildItem` /
`Test-Path` scan calls, mirroring fork `PS-Remove.psm1` ~lines 824-877.

### B4. Invoke-IPv4NetworkScan (P1 — three targeted fixes only)
Do NOT take the fork's full rewrite (it flips `-EnableMACResolving` to
`-DisableMACResolving`, a breaking parameter change). Only:
- Original line ~446: `for ($i = 0; $i -lt $Tries; i++)` → `$i++` (missing `$`; loop broken).
- Original line ~634: `TTL = $ResuJob_Resultlt.TTL` → the correct variable (check
  surrounding code; fork uses `$Job_Result.TTL`).
- OUI list download (~line 389): force TLS 1.2 before downloading
  `standards-oui.ieee.org`, add retry and fallback mirrors (Wireshark
  `https://www.wireshark.org/download/automated/data/manuf`, and maclookup.app) as fork
  `PS-Invoke.psm1` ~lines 894-966 does. Keep `C:\Ambitions\oui.txt`.

### B5. Add Invoke-WinGetInstall helper (P3 — new function)
Fork source: `PS-Install.psm1` (~lines 1594-1618). Self-contained, branding-free wrapper
adding `--source winget --disable-interactivity` + agreement flags to `winget install`.
Insert alphabetically into `ATG-PS-Invoke.txt`. After adding, optionally adopt it in
`Install-NetExtender`, `Install-WinGetApps`, and `Update-Edge` (each currently calls raw
`winget install`).

---

## BATCH C — `Functions/ATG-PS-Connect.txt` and `Functions/ATG-PS-Enable.txt`

### C1. Connect-Wifi (P1 — verbatim)
Fork source: `PS-Connect.psm1` (~lines 530-731). Original bugs: `$NetworkSSID` is
`Mandatory=$False` while `$NetworkPassword` is `Mandatory=$true` (backwards — open networks
impossible); async `Start-Process netsh` races profile-XML deletion; no XML escaping; no
error checks. Fork: SSID mandatory / password optional, synchronous netsh with
`$LASTEXITCODE` checks, XML-escaped SSID/password, UTF-8-no-BOM profile file, `user=all`,
Open/WPA3SAE support, auth/encryption combo validation, connection verification,
`Finally` cleanup. Branding-free; replace the whole original function.

### C2. Connect-O365AzureAD (P2 — warnings only)
Fork source: `PS-Connect.psm1` (~lines 68-133). Add the `Write-Warning` lines noting the
AzureAD module was retired 2024-03-30 and pointing to `Connect-MgGraph` / Microsoft.Graph,
plus the updated comment-help migration links. Keep the original behavior otherwise.

### C3. Enable-SSL (P2 — ADAPTED, do not copy fork verbatim)
Original enables TLS 1.2 + deprecated 1.1 + 1.0, session-only. Fork sets
`Tls12 -bor Tls13` and persists `SchUseStrongCrypto` machine-wide — but
`[Net.SecurityProtocolType]::Tls13` does not exist on older .NET Framework, and in the
fork's single expression that makes the whole `try` fall to `catch` (nothing gets set).
Implement instead:
1. Set TLS 1.2 via integer literal (`3072`), dropping 768/192 (TLS 1.1/1.0).
2. In a separate nested try/catch, attempt to add TLS 1.3 (`12288`); silently continue
   on failure.
3. Persist `SchUseStrongCrypto = 1` (DWORD) under
   `HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319` and `v2.0.50727`, plus the
   `Wow6432Node` equivalents on 64-bit — each write guarded with
   `-ErrorAction SilentlyContinue` (non-admin sessions must not throw).
Keep the function's existing Write-Host messaging style.

---

## BATCH D — Larger adaptations (do after A-C; each needs judgment)

**All of D1-D6 are complete.** Also completed since Batch D was written:
- Retired the dead `git.io/ATGPS` and `git.io/atgPS` shortlinks (GitHub retired the
  service) in `Scripts/Get-ATGPS.txt`, `Scripts/Deploy-ATGPSFunctions.txt`, and
  `README.md` — now point directly at the `raw.githubusercontent.com` URLs those
  shortlinks used to resolve to. `Scripts/misc/urls.txt` kept as an annotated
  historical record.
- Fixed `Update-O365Apps`'s channel check. It wasn't just the `*monthlty*` typo:
  `Get-Office365Version` is a nested function whose unqualified `$O365CurrentCdn`
  assignments created a local shadow variable instead of writing back to the
  `$global:O365CurrentCdn` the outer function declared, so the check always read an
  empty string and force-switched every machine to Monthly on every run regardless of
  its actual channel (confirmed identical in the fork). Fixed by having the nested
  function write `$global:O365CurrentCdn`, plus the spelling fix at the comparison site.

### D1. Set-DailyReboot / Set-WeeklyReboot BitLocker awareness (P2)
Fork source: `PS-Set.psm1` (~lines 175-240 and 465-537). Before the scheduled restart:
`Suspend-BitLocker -RebootCount 5` + a RunOnce resume script, preventing machines with
pre-boot PIN from stranding at the recovery prompt after the 3am reboot. Also adds
`-Time` (and `-Day` for weekly) parameters and replaces the fragile
`Triggers.StartBoundary.subString(0,16)` readout with `(Get-ScheduledTaskInfo).NextRunTime`.
ADAPT: fork writes breadcrumbs under `HKLM:\SOFTWARE\MauleTech` and scripts under
`$env:ProgramData\MauleTech` → use `HKLM:\SOFTWARE\Ambitions` and
`C:\Ambitions\Scripts\ResumeBitLocker.ps1`. Task names must not contain "MauleTech".

### D2. Install-O365 dynamic ODT fetch (P2)
Fork source: `PS-Install.psm1` (~lines 309-462). Take: `Get-ODTUri` (scrapes the current
Office Deployment Tool from Microsoft's download page — the original uses an aging static
`setup.exe` from download.ambitionsgroup.com), the `if ($TargetFile)` shortcut guards with
`$TargetFile = $null` resets (original creates broken shortcuts when Office is absent), and
optionally `-SharedComputer`/`-ConfigUrl`. KEEP the Ambitions site-config URL scheme
(`download.ambitionsgroup.com/Sites/<code>/<code>_O365_Config.xml`) and `C:\Ambitions\O365`.

### D3. Optimize-Powershell (P2)
Fork source: `PS-Optimize.psm1` (~lines 1-128). Take: (1) `Set-ExecutionPolicy ...
-ErrorAction SilentlyContinue` so GPO-locked machines don't throw; (2) the generated
profile's module-loading refactor (try `Import-Module` first, install only on failure, skip
the slow `Get-Module -ListAvailable` scan, only configure PSReadLine when the module
loaded); (3) profile load-time stopwatch instrumentation. KEEP the profile's loader line as
`irm ps.acgs.io | iex`. Prompt color changes optional.

### D4. Update-NTPDateTime + Get-NTPOffset (P2)
Fork source: `PS-Update.psm1` (`Get-NTPOffset` ~543-619, `Update-NTPDateTime` ~621-970).
Original opens a UDP socket with no timeouts (hangs forever when UDP 123 is filtered).
Take at minimum: `Get-NTPOffset` with 5-second send/receive timeouts, `finally` socket
disposal, admin check, and refusal to `Set-Date` when the query failed. The diagnostics
block is branding-free. If taking `-RegisterScheduledTask`, rename the task from
`MauleTech-NTPSync` to `Ambitions-NTPSync`.

### D5. Disable-SleepOnAC (P2)
Fork source: `PS-Disable.psm1` (~lines 164-200). The valuable part: lid-close and
power/sleep-button actions set to "do nothing" on AC plus `powercfg /setactive
SCHEME_CURRENT`. Review the fork's hardcoded DC timeouts (15/45 min) and 30-min AC display
timeout against Ambitions policy before adopting them.

### D6. Update-Everything BitLocker-safe reboot (P2)
Do NOT pull `Restart-ComputerSafely` (large fork-only function). Instead, before the
existing `Restart-Computer -Force`, insert:
`If ((Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue).ProtectionStatus -eq 'On') { Suspend-BitLocker -MountPoint $env:SystemDrive -RebootCount 1 }`

## Decisions resolved by the maintainer (do NOT redo or reconsider)

- **Set-AutoLogon: kept as-is, no code change.** The `$SiteCode + 'T3mpP@ss'` autologon
  password is intentionally temporary — it is overwritten by policy the moment the machine
  first touches the network, so the plaintext-registry/predictable-password weakness is not
  a real-world exposure window. Do not parameterize or otherwise change this function.
- **Update-PWSH choco-dependency retry: backported, including the helper.** Chocolatey v2
  sometimes reports a package as "failed to resolve dependency" when its dependency graph
  is inconsistent (a known choco v2 issue), and a plain `choco upgrade pwsh` fails outright
  in that state. Per maintainer decision, brought over both the fork's retry loop (up to 3
  attempts) and the `Repair-ChocoDependency` helper it depends on (`ATG-PS-Repair.txt`),
  which inspects choco's package cache/config, clears conflicting version pins, and
  re-registers affected sources between attempts.
- **Legacy root `ATG-PS-Functions.txt`: removed.** This file was a single-file, ~73-function
  concatenated snapshot that predates the per-verb file layout. It mattered because
  `Scripts/Get-ATGPS.txt` and `Scripts/Deploy-ATGPSFunctions.txt` both downloaded and
  `Import-Module`-ed this exact file — and per `Scripts/misc/urls.txt`, `ps.acgs.io` (the
  primary documented loader in `README.md`) resolves to `Get-ATGPS.txt`, so this was *not*
  a dead legacy path, it was load-bearing for production bootstrapping. Removing the file
  outright would have 404'd that path, so `Get-ATGPS.txt` and `Deploy-ATGPSFunctions.txt`
  were rewritten to fetch and concatenate the current per-verb files via
  `Functions/URL-List.csv` (previously unused dead weight in the repo) instead of the stale
  bundle — same `Import-Module -Name ATGPS` behavior, but now always current.

## Decision-needed items (do NOT implement without maintainer approval)

- **Invoke-NDDCScan webhook (P2, security):** original embeds a base64-obfuscated Ambitions
  Teams webhook URL in this public repo. Maintainer decision: leave as-is for now — do NOT
  externalize or rotate this without explicit sign-off.
- **Invoke-ValidatedDownload infrastructure: REJECTED, do not implement.** SHA256-manifest
  download validation (fork `PS-Invoke.psm1` ~1656+ plus `DownloadManifest.json`) needs a
  manifest that is kept current every time a download URL in this repo changes — a hash
  goes stale the moment the upstream vendor ships a new build, and a stale/missing entry
  either blocks scheduled/RMM runs outright or silently downgrades to "no validation." That
  upkeep requires an assigned maintainer, which this repo does not have guaranteed. Skip it
  entirely rather than land infrastructure with an unmet maintenance requirement.

## New fork functions worth cherry-picking later (P3, optional)

Enable-RDP, Enable-RemoteManagement, Enable-DellTPM, Disable-EdgeOOBE,
Expand-SystemPartition, Restart-ComputerSafely (+ ConvertTo-EncodedCommand),
Remove-StaleProfiles, Remove-OrphanedInstallerFiles, Repair-DomainTrust, Repair-RemoteWMI,
Repair-NTPConfiguration, Repair-ChocoDependency, Get-PowerShellHealth,
Get-DotNetFrameworkVersion, Get-ADLockedAccount, Get-ADUsersPasswordExpiring,
Update-OEMDrivers, Update-WindowsTo11, Export-ExchangeDistributionList,
Add-RDPShortcut (+ Add-RDPCertificate), Send-Item/Receive-Item (+ croc helpers).

## Explicitly NOT to backport

- Any `C:\Ambitions` → `$ITFolder` or Ambitions-URL → MauleTech-URL substitution
  (branding). This includes loader lines, download.ambitionsgroup.com hosts, ITGlue links,
  and task names.
- `Convert-ComputerFleetReport`: the ORIGINAL is newer than the fork here. Do not touch.
- `Install-WinRepairToolbox`: fork commented out the Ambitions customization step
  (regression for us).
- `Export-UnifiDevicesToItGlue`: fork deleted it (ATG-specific); we keep it.
- Fork deletions of Ambitions-specific functions generally.
