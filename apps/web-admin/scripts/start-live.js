const { spawn } = require('child_process');
const path = require('path');
const http = require('http');

const adminDir = path.resolve(__dirname, '..');
const PORT = process.env.PORT || 3000;

console.log('------------------------------------------------------------');
console.log('🚀 Starting SalesArmy Web Admin Portal...');
console.log('------------------------------------------------------------');

// 1. Start Web Admin Server
const serverProcess = spawn(process.execPath, ['server.js'], {
  cwd: adminDir,
  env: { ...process.env, PORT: String(PORT) },
  stdio: ['inherit', 'pipe', 'pipe']
});

let serverReady = false;

serverProcess.stdout.on('data', (data) => {
  const text = data.toString();
  if (text.includes('server.listen') || text.includes('Web Portal:')) {
    serverReady = true;
  }
  // forward useful logs
  process.stdout.write(data);
});

serverProcess.stderr.on('data', (data) => {
  process.stderr.write(data);
});

// 2. Poll until server is ready, then launch tunnel
function waitForServer(retries = 30) {
  if (retries <= 0) {
    console.error('❌ Server took too long to start.');
    cleanup();
    process.exit(1);
  }

  const req = http.get(`http://127.0.0.1:${PORT}/`, (res) => {
    startTunnel();
  });

  req.on('error', () => {
    setTimeout(() => waitForServer(retries - 1), 500);
  });
}

let tunnelProcess = null;

function startTunnel() {
  console.log('\n🌐 Creating Instant Public HTTPS Tunnel via Cloudflare...');
  console.log('⏳ Connecting to Cloudflare global network...\n');

  // Use npx cloudflared (built-in zero-setup tunnel)
  const isWin = process.platform === 'win32';
  const npxCmd = isWin ? 'npx.cmd' : 'npx';

  // Node >= 18.20 / 20.12 refuses to spawn .cmd files without a shell on
  // Windows (EINVAL), so run npx through the shell there. Arguments are fixed.
  tunnelProcess = spawn(npxCmd, ['--yes', 'cloudflared', 'tunnel', '--url', `http://127.0.0.1:${PORT}`], {
    stdio: ['ignore', 'pipe', 'pipe'],
    shell: isWin,
  });

  let urlFound = false;

  const handleTunnelOutput = (data) => {
    const text = data.toString();
    // Real quick-tunnel URLs look like https://word-word-word.trycloudflare.com.
    // "api.trycloudflare.com" is Cloudflare's own service and only appears in
    // error messages when the tunnel could NOT be created — never report it.
    const match = [...text.matchAll(/https:\/\/([a-zA-Z0-9-]+)\.trycloudflare\.com/g)]
      .find(m => m[1].toLowerCase() !== 'api');
    if (!urlFound && /failed to request quick tunnel|connection reset|i\/o timeout|no such host/i.test(text)) {
      console.error('\n❌ Could not create the Cloudflare tunnel. Your network is blocking trycloudflare.com.');
      console.error('   Try a mobile hotspot, or deploy the server (Render / Cloudflare / Hostinger).');
      console.error('   Details: ' + text.trim().split('\n').slice(-1)[0]);
    }
    if (match && !urlFound) {
      urlFound = true;
      const publicUrl = match[0];
      console.log('============================================================');
      console.log('🎉 SALESARMY WEB ADMIN IS NOW LIVE AND PUBLICLY ACCESSIBLE!');
      console.log('============================================================');
      console.log(`🔗 Public Live URL : ${publicUrl}`);
      console.log(`💻 Local URL       : http://localhost:${PORT}`);
      console.log('------------------------------------------------------------');
      console.log('🔑 Sign in with your Super Admin account (profiles.role = super_admin).');
      console.log('   Anyone with this URL can reach the login page — stop the tunnel when done.');
      console.log('============================================================\n');
      console.log('Press Ctrl+C to stop the live server and close the tunnel.\n');
    }
  };

  tunnelProcess.stdout.on('data', handleTunnelOutput);
  tunnelProcess.stderr.on('data', handleTunnelOutput);

  tunnelProcess.on('exit', (code) => {
    if (!urlFound) {
      console.log('Cloudflare tunnel ended with code', code);
    }
  });
}

function cleanup() {
  console.log('\n🛑 Shutting down server and live tunnel...');
  if (tunnelProcess) {
    try {
      if (process.platform === 'win32') {
        spawn('taskkill', ['/pid', String(tunnelProcess.pid), '/f', '/t']);
      } else {
        tunnelProcess.kill('SIGINT');
      }
    } catch (_) {}
  }
  if (serverProcess) {
    try {
      if (process.platform === 'win32') {
        spawn('taskkill', ['/pid', String(serverProcess.pid), '/f', '/t']);
      } else {
        serverProcess.kill('SIGINT');
      }
    } catch (_) {}
  }
}

process.on('SIGINT', () => {
  cleanup();
  setTimeout(() => process.exit(0), 500);
});

process.on('SIGTERM', () => {
  cleanup();
  setTimeout(() => process.exit(0), 500);
});

// Begin polling
waitForServer();

