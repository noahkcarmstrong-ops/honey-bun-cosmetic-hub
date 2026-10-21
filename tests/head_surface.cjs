const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'avatar.lua'), 'utf8');
const block = source.slice(source.indexOf('    local function applyPartAppearance('), source.indexOf('    local function fitBodyJoints('));
if (!block.includes('end')) throw new Error('Appearance copier missing');
const generated = path.join(__dirname, '.head_surface.generated.lua');
try {
  fs.writeFileSync(generated, block + fs.readFileSync(path.join(__dirname, 'head_surface.lua'), 'utf8'));
  const result = spawnSync('npx --offline --package=fengari-node-cli fengari tests/.head_surface.generated.lua', {cwd:root,shell:true,encoding:'utf8'});
  process.stdout.write(result.stdout || ''); process.stderr.write(result.stderr || '');
  if (result.status || !result.stdout.includes('PASS:')) process.exitCode = 1;
} finally { fs.unlinkSync(generated); }
