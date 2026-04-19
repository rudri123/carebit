const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const {
  buildFirebaseLaunchConfig,
  buildFirebaseToolEnv,
  buildMissingJavaMessage,
  buildOutdatedJavaMessage,
  parseJavaMajorVersion,
  readValidJavaHome,
  resolveJavaRuntime,
} = require('../scripts/start-emulators.cjs');

test('parseJavaMajorVersion reads current Java version strings', () => {
  assert.equal(
    parseJavaMajorVersion('openjdk version "21.0.2" 2024-01-16'),
    21,
  );
  assert.equal(
    parseJavaMajorVersion('java version "17.0.10" 2024-01-16 LTS'),
    17,
  );
  assert.equal(
    parseJavaMajorVersion('java version "1.8.0_401"'),
    8,
  );
});

test('Java preflight messages include actionable setup guidance', () => {
  const missingJavaMessage = buildMissingJavaMessage();
  const outdatedJavaMessage = buildOutdatedJavaMessage(
    8,
    'java version "1.8.0_401"',
  );

  assert.match(missingJavaMessage, /brew install openjdk@21/);
  assert.match(missingJavaMessage, /where java/);
  assert.match(missingJavaMessage, /Cloud Firestore emulator/);
  assert.match(outdatedJavaMessage, /requires Java JDK 21 or higher/);
  assert.match(outdatedJavaMessage, /1.8.0_401/);
});

test('buildFirebaseLaunchConfig prefers a local firebase-tools install', () => {
  const tempRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), 'carebit-start-emulators-local-cli-'),
  );
  const entrypoint = path.join(
    tempRoot,
    'node_modules',
    'firebase-tools',
    'lib',
    'bin',
    'firebase.js',
  );

  fs.mkdirSync(path.dirname(entrypoint), { recursive: true });
  fs.writeFileSync(entrypoint, '');

  const launchConfig = buildFirebaseLaunchConfig({
    platform: 'win32',
    execPath: 'C:\\Program Files\\nodejs\\node.exe',
    comspec: 'C:\\Windows\\System32\\cmd.exe',
    rootDir: tempRoot,
  });

  assert.equal(launchConfig.command, 'C:\\Program Files\\nodejs\\node.exe');
  assert.deepEqual(launchConfig.args, [
    entrypoint,
    'emulators:start',
    '--only',
    'functions,firestore',
  ]);
  assert.equal(launchConfig.options.shell, false);
  assert.equal(launchConfig.options.stdio, 'inherit');
  assert.equal(launchConfig.options.env, process.env);
});

test('buildFirebaseLaunchConfig uses cmd.exe for Windows PATH resolution', () => {
  const launchConfig = buildFirebaseLaunchConfig({
    platform: 'win32',
    comspec: 'C:\\Windows\\System32\\cmd.exe',
    rootDir: path.join(os.tmpdir(), 'carebit-start-emulators-no-local-cli'),
  });

  assert.equal(launchConfig.command, 'C:\\Windows\\System32\\cmd.exe');
  assert.deepEqual(launchConfig.args, [
    '/d',
    '/s',
    '/c',
    'firebase emulators:start --only functions,firestore',
  ]);
  assert.equal(launchConfig.options.shell, false);
  assert.equal(launchConfig.options.stdio, 'inherit');
  assert.equal(launchConfig.options.env, process.env);
});

test('buildFirebaseLaunchConfig uses firebase directly on non-Windows hosts', () => {
  const launchConfig = buildFirebaseLaunchConfig({
    platform: 'linux',
    rootDir: path.join(os.tmpdir(), 'carebit-start-emulators-linux'),
  });

  assert.equal(launchConfig.command, 'firebase');
  assert.deepEqual(launchConfig.args, [
    'emulators:start',
    '--only',
    'functions,firestore',
  ]);
  assert.equal(launchConfig.options.shell, false);
  assert.equal(launchConfig.options.stdio, 'inherit');
  assert.equal(launchConfig.options.env, process.env);
});

test('readValidJavaHome returns a path only when bin/java exists', () => {
  const tempRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), 'carebit-java-home-validation-'),
  );
  const javaHome = path.join(tempRoot, 'jdk-21');

  fs.mkdirSync(path.join(javaHome, 'bin'), { recursive: true });
  fs.writeFileSync(path.join(javaHome, 'bin', 'java'), '');

  assert.equal(readValidJavaHome(javaHome), javaHome);
  assert.equal(readValidJavaHome(path.join(tempRoot, 'missing')), null);
});

test('resolveJavaRuntime prepends JAVA_HOME bin directory to PATH', () => {
  const tempRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), 'carebit-java-runtime-resolution-'),
  );
  const javaHome = path.join(tempRoot, 'jdk-21');
  const javaBin = path.join(javaHome, 'bin');

  fs.mkdirSync(javaBin, { recursive: true });
  fs.writeFileSync(path.join(javaBin, 'java'), '');

  const runtime = resolveJavaRuntime({
    JAVA_HOME: javaHome,
    PATH: '/usr/bin:/bin',
  });

  assert.equal(runtime.javaHome, javaHome);
  assert.equal(runtime.javaCommand, path.join(javaBin, 'java'));
  assert.equal(runtime.env.JAVA_HOME, javaHome);
  assert.match(
    runtime.env.PATH,
    new RegExp(`^${javaBin.replace(/[.*+?^${}()|[\]\\\\]/g, '\\$&')}`),
  );
});

test('buildFirebaseToolEnv uses a repo-local cache directory', () => {
  const tempRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), 'carebit-firebase-tool-env-'),
  );
  const toolEnv = buildFirebaseToolEnv({
    env: { PATH: '/usr/bin:/bin' },
    rootDir: tempRoot,
  });

  assert.equal(toolEnv.HOME, path.join(tempRoot, '.home'));
  assert.equal(toolEnv.XDG_CACHE_HOME, path.join(tempRoot, '.cache'));
  assert.equal(toolEnv.XDG_CONFIG_HOME, path.join(tempRoot, '.home', '.config'));
  assert.equal(
    fs.existsSync(path.join(tempRoot, '.cache', 'firebase', 'runtime')),
    true,
  );
  assert.equal(
    fs.existsSync(path.join(tempRoot, '.home', '.config')),
    true,
  );
});
