// ============================================================
// github-api.js
// GitHub API wrapper for ItsOuaail/my-site
// Usage: node scripts/github-api.js
// Requires: GITHUB_TOKEN environment variable
// ============================================================

const https = require('https');

const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const OWNER = 'ItsOuaail';
const REPO  = 'my-site';

if (!GITHUB_TOKEN) {
  console.error('ERROR: GITHUB_TOKEN environment variable is not set.');
  console.error('Run: $env:GITHUB_TOKEN="your_token_here"  (PowerShell)');
  process.exit(1);
}

// ── Base request function ─────────────────────────────────
function githubRequest(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'api.github.com',
      path,
      method,
      headers: {
        'Authorization':        `Bearer ${GITHUB_TOKEN}`,
        'Accept':               'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent':           'ouaail-deploy-script',
        'Content-Type':         'application/json',
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(data) }); }
        catch { resolve({ status: res.statusCode, body: data }); }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

function repoPath(endpoint) {
  return `/repos/${OWNER}/${REPO}${endpoint}`;
}

// ── 1. List recent workflow runs ──────────────────────────
async function listWorkflowRuns() {
  console.log('\n📋 RECENT WORKFLOW RUNS');
  console.log('─'.repeat(50));
  const res = await githubRequest('GET', repoPath('/actions/runs?per_page=5'));
  const runs = res.body.workflow_runs || [];
  if (runs.length === 0) { console.log('  No runs found.'); return; }
  runs.forEach(r => {
    const icon = r.conclusion === 'success' ? '✅' : r.conclusion === 'failure' ? '❌' : '⏳';
    console.log(`  ${icon} #${r.run_number} | ${r.name}`);
    console.log(`     Branch    : ${r.head_branch}`);
    console.log(`     Status    : ${r.status} / ${r.conclusion ?? 'in progress'}`);
    console.log(`     Triggered : ${new Date(r.created_at).toLocaleString()}`);
    console.log(`     URL       : ${r.html_url}`);
    console.log('');
  });
}

// ── 2. List deployments ───────────────────────────────────
async function listDeployments() {
  console.log('\n🚀 RECENT DEPLOYMENTS');
  console.log('─'.repeat(50));
  const res = await githubRequest('GET', repoPath('/deployments?per_page=5'));
  const deployments = res.body;
  if (!Array.isArray(deployments) || deployments.length === 0) {
    console.log('  No deployments found yet.');
    return;
  }
  for (const d of deployments) {
    const statusRes = await githubRequest('GET', repoPath(`/deployments/${d.id}/statuses`));
    const latestStatus = statusRes.body[0]?.state ?? 'unknown';
    const icon = latestStatus === 'success' ? '✅' : latestStatus === 'failure' ? '❌' : '⏳';
    console.log(`  ${icon} Deployment #${d.id}`);
    console.log(`     Environment : ${d.environment}`);
    console.log(`     Branch/SHA  : ${d.ref} (${d.sha.substring(0, 7)})`);
    console.log(`     Status      : ${latestStatus}`);
    console.log(`     Created     : ${new Date(d.created_at).toLocaleString()}`);
    console.log('');
  }
}

// ── 3. Trigger workflow manually ─────────────────────────
async function triggerWorkflow() {
  console.log('\n⚡ TRIGGERING WORKFLOW (deploy.yml on main)');
  console.log('─'.repeat(50));
  const res = await githubRequest(
    'POST',
    repoPath('/actions/workflows/deploy.yml/dispatches'),
    { ref: 'main' }
  );
  if (res.status === 204) {
    console.log('  ✅ Workflow triggered successfully!');
    console.log('  Check: https://github.com/ItsOuaail/my-site/actions');
  } else {
    console.log(`  ❌ Failed (status ${res.status}):`, res.body);
  }
}

// ── 4. Get repo info ──────────────────────────────────────
async function getRepoInfo() {
  console.log('\n📦 REPO INFO');
  console.log('─'.repeat(50));
  const res = await githubRequest('GET', repoPath(''));
  const r = res.body;
  console.log(`  Name        : ${r.full_name}`);
  console.log(`  Default     : ${r.default_branch}`);
  console.log(`  Private     : ${r.private}`);
  console.log(`  Last push   : ${new Date(r.pushed_at).toLocaleString()}`);
  console.log(`  URL         : ${r.html_url}`);
}

// ── MAIN ──────────────────────────────────────────────────
(async () => {
  console.log('============================================');
  console.log('  GitHub API — ItsOuaail/my-site');
  console.log('============================================');

  await getRepoInfo();
  await listWorkflowRuns();
  await listDeployments();

  // Uncomment the line below to manually trigger a deployment:
  // await triggerWorkflow();
})();
