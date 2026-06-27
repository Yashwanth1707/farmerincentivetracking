const { spawn } = require('child_process');
const path = require('path');

const root = path.resolve(__dirname, '..');

const backend = spawn('npm', ['--prefix', 'backend', 'run', 'dev'], {
  cwd: root,
  stdio: 'inherit',
  shell: true,
});

const frontend = spawn('cd', ['frontend', '&&', 'flutter', 'run', '-d', 'web-server', '--web-port', '3000'], {
  cwd: root,
  stdio: 'inherit',
  shell: true,
});

const shutdown = () => {
  backend.kill('SIGTERM');
  frontend.kill('SIGTERM');
  process.exit(0);
};

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

backend.on('exit', (code) => {
  if (code && code !== 0) {
    frontend.kill('SIGTERM');
    process.exit(code);
  }
});

frontend.on('exit', (code) => {
  if (code && code !== 0) {
    backend.kill('SIGTERM');
    process.exit(code);
  }
});
