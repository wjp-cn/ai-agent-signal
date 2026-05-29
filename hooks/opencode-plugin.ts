import type { Plugin } from "@opencode-ai/plugin"
import { execFileSync } from "node:child_process"
import { join } from "node:path"
import { readFileSync } from "node:fs"

const STATUS_WRITER = join(import.meta.dirname, "..", "status_writer.ps1")

let currentPattern = 4
let idleCooldown: ReturnType<typeof setTimeout> | null = null

function getConfigPath(): string {
  return join(import.meta.dirname, "..", "config.json")
}

function getStatusFile(): string {
  try {
    const cfg = JSON.parse(readFileSync(getConfigPath(), "utf-8"))
    if (cfg.statusFile) {
      return cfg.statusFile.replace("~", process.env.USERPROFILE || "")
    }
  } catch {
    // config file missing or invalid
  }
  return join(process.env.USERPROFILE || "", ".traffic-light", "status.json")
}

function writePattern(pattern: number, yellow = false, yellowFlash = false) {
  try {
    const args = [
      "-ExecutionPolicy", "Bypass",
      "-File", STATUS_WRITER,
      "-Pattern", String(pattern),
      "-Tool", "opencode",
      "-Yellow", String(yellow),
      "-YellowFlash", String(yellowFlash),
      "-StatusFile", getStatusFile()
    ]
    execFileSync("powershell", args, { timeout: 5000, stdio: "ignore" })
    currentPattern = pattern
  } catch {
    // status write failed
  }
}

function setPattern(pattern: number) {
  if (idleCooldown) return
  if (currentPattern !== pattern) {
    writePattern(pattern)
  }
}

function setIdle() {
  writePattern(4)
  if (idleCooldown) clearTimeout(idleCooldown)
  idleCooldown = setTimeout(() => { idleCooldown = null }, 1000)
}

export default (async () => {
  writePattern(4)

  return {
    "tool.execute.before": async () => {
      setPattern(1)
    },
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        setIdle()
      }
      if (event.type === "question.asked") {
        if (idleCooldown) {
          clearTimeout(idleCooldown)
          idleCooldown = null
        }
        writePattern(0, true, true)
      }
      if (event.type === "question.replied") {
        writePattern(4, false, false)
      }
      if (event.type === "tui.prompt.append") {
        if (idleCooldown) {
          clearTimeout(idleCooldown)
          idleCooldown = null
        }
        writePattern(3)
      }
      if (event.type === "message.updated") {
        setPattern(5)
      }
    }
  }
}) satisfies Plugin
