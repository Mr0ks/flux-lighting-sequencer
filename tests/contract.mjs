import assert from "node:assert/strict";
import fs from "node:fs";

const html = fs.readFileSync(new URL("../index.html", import.meta.url), "utf8");
const server = fs.readFileSync(
  new URL("../roblox/Server.lua", import.meta.url),
  "utf8",
);
const client = fs.readFileSync(
  new URL("../roblox/Client.lua", import.meta.url),
  "utf8",
);
const installer = fs.readFileSync(
  new URL("../roblox/Installer.lua", import.meta.url),
  "utf8",
);
const version = fs.readFileSync(
  new URL("../version.js", import.meta.url),
  "utf8",
);

const htmlVersion = html.match(
  /meta name="flux-sequencer-version" content="([^"]+)"/,
)?.[1];
const latestVersion = version.match(/fluxLatestVersion = "([^"]+)"/)?.[1];
assert.ok(htmlVersion, "index.html must declare a release");
assert.equal(htmlVersion, latestVersion, "release files must stay in sync");

for (const action of [
  "level",
  "flash",
  "reset",
  "color",
  "pan",
  "tilt",
  "spin",
  "pitch",
  "beam intensity",
  "gobo intensity",
  "iris",
  "width",
  "shutter",
  "strobe",
  "pyro",
  "block",
]) {
  assert.ok(server.includes(`"${action}"`), `Roblox runtime is missing ${action}`);
}

for (const fixture of [
  "profile",
  "wash",
  "magic blade",
  "magic panel",
  "jdc1",
  "q7",
  "laser",
  "line",
  "par",
  "blinder",
  "atomic",
  "display",
  "follow spotlight",
]) {
  assert.ok(
    server.includes(fixture) || html.includes(fixture),
    `fixture contract is missing ${fixture}`,
  );
}

assert.match(server, /local function orderedModels/);
assert.match(server, /selected\[index\]/);
assert.match(server, /module == 2.*Centre pixels/);
assert.match(server, /module == 3.*Outer tube/);
assert.match(server, /audioReady/);
assert.match(server, /workspace:GetServerTimeNow\(\) - started/);
assert.match(server, /emitterSerialIsCurrent/);
assert.match(client, /PREPARING AUDIO/);
assert.match(client, /ContentProvider:PreloadAsync\(\{ localSound \}\)/);
assert.match(client, /workspace:GetServerTimeNow\(\) - data.started/);
assert.match(installer, /Enum\.RunContext\.Client/);
assert.match(installer, /92368439343389/);
assert.match(html, /function nativeMetadata/);
assert.match(html, /custom\?\.actions/);
assert.match(html, /fixtureTypes = null/);
assert.match(html, /Flash · fade in\/out/);
assert.match(html, /samplesPerPixel = d.length \/ contentWidth/);
assert.doesNotMatch(html, /\.flux\.json/i);

const inlineScripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
  .map((match) => match[1])
  .filter(Boolean);
for (const source of inlineScripts) new Function(source);

console.log(
  `Flux Sequencer ${htmlVersion}: fixture, runtime, import, and JavaScript contracts passed.`,
);
