// Builds the Tauri updater manifest (latest.json) from the signed NSIS bundle.
// Run in CI on a release tag after `tauri build`.
// Env: TAG (the git tag, e.g. v1.18.1).
import { readFileSync, writeFileSync, readdirSync, existsSync } from "fs";
import { join } from "path";

const tag = process.env.TAG;
if (!tag) { console.error("TAG env is required"); process.exit(1); }

const conf = JSON.parse(readFileSync("src-tauri/tauri.conf.json", "utf8"));
const version = conf.version;

const nsisDir = "src-tauri/target/release/bundle/nsis";
if (!existsSync(nsisDir)) {
  console.log("NSIS directory not found, skipping latest.json");
  process.exit(0);
}

const files = readdirSync(nsisDir);
const exe = files.find((f) => f.endsWith("-setup.exe"));
const sig = files.find((f) => f.endsWith("-setup.exe.sig"));
if (!exe) {
  console.error("missing NSIS setup exe in", nsisDir, files);
  process.exit(1);
}

if (!sig) {
  console.log("No updater signature found (.sig), skipping latest.json generation");
  process.exit(0);
}

const signature = readFileSync(join(nsisDir, sig), "utf8").trim();
const repo = process.env.GITHUB_REPOSITORY || "amansaxna/agentPet";
const url = `https://github.com/${repo}/releases/download/${tag}/${encodeURIComponent(exe)}`;

const latest = {
  version,
  notes: "AgentPet for Windows, see the release notes.",
  pub_date: new Date().toISOString(),
  platforms: { "windows-x86_64": { signature, url } },
};

writeFileSync("latest.json", JSON.stringify(latest, null, 2));
console.log("wrote latest.json", { version, exe });
