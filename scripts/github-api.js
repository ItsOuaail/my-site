// GitHub API wrapper — manage repos, deployments, secrets programmatically
const https = require('https');

const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const OWNER = 'ItsOuaail';
const REPO = 'my-site';

// Base request function
function githubRequest(method, endpoint, body = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'api.github.com',
      path: `/repos/${OWNER}/${REPO}${endpoint}`,
      method,
      headers: {
        'Authorization': `Bearer ${GITHUB_TOKEN}`,
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'MyDeployScript',
        'Content-Type': 'application/json',
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve(JSON.parse(data)));
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

// List all deployments
async function listDeployments() {
  const deployments = await githubRequest('GET', '/deployments');
  console.log('Deployments:', deployments.map(d => ({
    id: d.id,
    environment: d.environment,
    created_at: d.created_at,
    sha: d.sha.substring(0, 7),
  })));
}

// Create a deployment
async function createDeployment(ref = 'main', environment = 'production') {
  const deployment = await githubRequest('POST', '/deployments', {
    ref,
    environment,
    description: `Deploy ${ref} to ${environment}`,
    auto_merge: false,
    required_contexts: [],
  });
  console.log('Created deployment:', deployment.id);
  return deployment;
}

// Update deployment status
async function updateDeploymentStatus(deploymentId, state, logUrl) {
  // state: error | failure | inactive | in_progress | queued | pending | success
  await githubRequest('POST', `/deployments/${deploymentId}/statuses`, {
    state,
    log_url: logUrl,
    description: `Deployment ${state}`,
    environment: 'production',
  });
  console.log(`Deployment ${deploymentId} marked as: ${state}`);
}

// Trigger a workflow run via API
async function triggerWorkflow(workflowFile = 'deploy.yml', ref = 'main') {
  const result = await githubRequest(
    'POST',
    `/actions/workflows/${workflowFile}/dispatches`,
    { ref, inputs: {} }
  );
  console.log('Workflow triggered:', result);
}

// List workflow runs
async function listWorkflowRuns() {
  const result = await githubRequest('GET', '/actions/runs');
  console.log('Recent runs:', result.workflow_runs?.map(r => ({
    id: r.id,
    status: r.status,
    conclusion: r.conclusion,
    branch: r.head_branch,
    created_at: r.created_at,
  })));
}

// Run it
(async () => {
  await listDeployments();
  await listWorkflowRuns();
})();
