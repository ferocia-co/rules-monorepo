import { spawn } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import { chromium } from 'playwright';

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function contentType(filePath) {
  if (filePath.endsWith('.js')) {
    return 'text/javascript';
  }
  if (filePath.endsWith('.css')) {
    return 'text/css';
  }
  if (filePath.endsWith('.html')) {
    return 'text/html';
  }
  return 'application/octet-stream';
}

function startServer(root) {
  const server = http.createServer((request, response) => {
    const requestPath = new URL(request.url ?? '/', 'http://127.0.0.1')
      .pathname;
    const relativePath =
      requestPath === '/' ? 'index.html' : requestPath.slice(1);
    const filePath = path.join(root, relativePath);

    if (
      !filePath.startsWith(root) ||
      !fs.existsSync(filePath) ||
      fs.statSync(filePath).isDirectory()
    ) {
      response.writeHead(404);
      response.end('not found');
      return;
    }

    response.writeHead(200, { 'content-type': contentType(filePath) });
    response.end(fs.readFileSync(filePath));
  });

  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve(server));
  });
}

async function main() {
  const root = path.resolve('dist');
  const indexPath = path.join(root, 'index.html');

  if (!fs.existsSync(indexPath)) {
    await new Promise((resolve, reject) => {
      const child = spawn('node', ['node_modules/vite/bin/vite.js', 'build'], {
        env: process.env,
        stdio: 'inherit',
      });
      child.on('exit', (code) => {
        if (code === 0) {
          resolve();
        } else {
          reject(new Error(`vite build failed with exit code ${code}`));
        }
      });
    });
  }

  const server = await startServer(root);
  const port = server.address().port;
  const executablePath = process.env.FEROCIA_PLAYWRIGHT_CHROMIUM_HEADLESS_SHELL;
  const browser = await chromium.launch({
    executablePath,
    headless: true,
  });

  try {
    const page = await browser.newPage();
    await page.goto(`http://127.0.0.1:${port}/`);
    await delay(100);
    const text = await page.textContent('[data-testid="status"]');
    assert(text === 'Status: ready', `unexpected status text: ${text}`);
  } finally {
    await browser.close();
    await new Promise((resolve) => server.close(resolve));
  }
}

await main();
