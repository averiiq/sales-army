const fs = require('fs');
const path = require('path');
const https = require('https');

function loadEnv() {
  const envPaths = [
    path.join(__dirname, '..', '.env'),
    path.join(__dirname, '..', '..', '..', '.env')
  ];
  for (const envPath of envPaths) {
    if (fs.existsSync(envPath)) {
      const content = fs.readFileSync(envPath, 'utf8');
      content.split('\n').forEach(line => {
        const match = line.match(/^\s*([\w.-]+)\s*=\s*(.*)?\s*$/);
        if (match) {
          const key = match[1];
          let value = (match[2] || '').trim();
          if (value.startsWith('"') && value.endsWith('"')) value = value.slice(1, -1);
          if (value.startsWith("'") && value.endsWith("'")) value = value.slice(1, -1);
          if (!process.env[key]) process.env[key] = value;
        }
      });
    }
  }
}
loadEnv();

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;

function get(endpoint) {
  return new Promise(resolve => {
    const fullUrl = new URL(`${url.replace(/\/$/, '')}/rest/v1/${endpoint}`);
    const headers = {
      'apikey': key,
      'Authorization': `Bearer ${key}`
    };
    https.get(fullUrl, { headers }, res => {
      let b = '';
      res.on('data', c => b += c);
      res.on('end', () => resolve({ status: res.statusCode, body: b }));
    });
  });
}

async function run() {
  const res = await get('platform_settings?id=in.(remote_config,pricing_and_plans,broadcast)&select=id,data');
  const rows = JSON.parse(res.body);
  for (const row of rows) {
    console.log(`\n=== ROW: ${row.id} ===`);
    console.log(JSON.stringify(row.data, null, 2));
  }
}

run();
