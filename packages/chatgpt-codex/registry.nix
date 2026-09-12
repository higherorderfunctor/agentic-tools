{repoPath, ...}: {
  checks.cacheHitParity.chatgpt-codex = {consumerPath = ["ai" "chatgpt-codex"];};
  documentation.aiCliDescriptions.chatgpt-codex = "OpenAI Codex CLI";
  update.targets.chatgpt-codex = {flags = ["--use-update-script" "--override-filename" (repoPath ./packages/ai/chatgpt-codex/package.nix)];};
}
