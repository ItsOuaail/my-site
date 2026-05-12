# my-site — StopwatchApp CI/CD Pipeline

Automated deployment of StopwatchApp to IIS on SIRIUS1 via GitHub Actions + SSH.

## Stack
- **App:** ASP.NET Core 8 / Blazor Server
- **Server:** SIRIUS1 (Windows Server + IIS)
- **Domain:** ouaail-stopwatch.ms-strategies.com
- **CI/CD:** GitHub Actions 

## How it works

Every push to `main` automatically:
1. Builds the .NET 8 app in Release mode
2. Publishes the output
3. Waits for approval (GitHub Environment: `production`)
4. Connects to SIRIUS1 via SSH
5. Stops IIS, backs up old version, deploys new files, restarts IIS
6. Verifies the site is running — rolls back automatically if it fails

## GitHub Secrets required

| Secret | Value |
|---|---|
| `SERVER_HOST` | `SERVER_HOST` |
| `SERVER_USER` | `SERVER_USER` |
| `SSH_PRIVATE_KEY` | *(your SSH private key)* |

## Manual trigger

You can trigger a deployment manually from the GitHub Actions tab,
or via the API script:

```powershell
$env:GITHUB_TOKEN="your_token"
node scripts/github-api.js
