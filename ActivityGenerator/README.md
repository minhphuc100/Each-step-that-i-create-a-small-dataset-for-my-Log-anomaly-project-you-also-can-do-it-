# ActivityGenerator

ActivityGenerator simulates normal Windows client activity in an AD DS lab. It is meant to create realistic, benign endpoint and domain-controller log noise for a small log anomaly dataset project.

## What it does

- Creates and reads local work files.
- Optionally copies files to a configured SMB share.
- Creates Word and Excel activity when Microsoft Office is installed.
- Falls back to `.txt` and `.csv` files when Office is not installed.
- Performs normal DNS, web, domain, and port checks.
- Inserts idle time between actions.
- Writes JSONL activity logs under `logs/`.

## Project structure

```text
ActivityGenerator/
|-- main.ps1
|-- config.json
|-- modules/
|   |-- file.ps1
|   |-- office.ps1
|   |-- idle.ps1
|   `-- network.ps1
|-- scheduler.ps1
|-- logger.ps1
`-- README.md
```

## Quick start

Open PowerShell on the Windows 11 client VM:

```powershell
cd .\ActivityGenerator
powershell.exe -ExecutionPolicy Bypass -File .\main.ps1
```

For a single test action:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\main.ps1 -Once
```

## Configure for your lab

Edit `config.json` before running:

- `identity.domainName`: your AD domain, for example `lab.local`.
- `identity.domainController`: your domain controller FQDN, for example `DC01.lab.local`.
- `paths.networkShare`: a shared folder path, for example `\\DC01\Shared`.
- `run.iterations`: how many activity cycles to run.
- `run.minDelaySeconds` and `run.maxDelaySeconds`: random wait range between activities.

If the share is not available, the script logs a warning and continues.

## Log output

Each run creates a JSONL file in `logs/`. Each line contains:

- Timestamp
- Computer name
- Domain user
- Module
- Action
- Status
- Message
- Extra data

This helps you compare what the generator attempted with Windows Event Viewer, domain controller logs, Sysmon, or your log pipeline.

## Notes

Run this only inside your own lab. The script is intentionally limited to ordinary user-like actions and does not attempt stealth, privilege escalation, credential access, or destructive behavior.
