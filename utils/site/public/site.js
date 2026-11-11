// Fixed illustrations of documented examples, not a browser policy engine.
const scenarios = {
  internal: {
    code: "FLOW / 01",
    destination: "Internal workspace",
    terms: "Matching destination terms",
    result: "The internal write is allowed.",
    description:
      "The verified summary retains the report’s restrictions and meets the internal destination’s requirements.",
    command: "bend examples/Flow.bend",
    outcome: "allowed",
    icon: "✓",
  },
  public: {
    code: "FLOW / 02",
    destination: "Public workspace",
    terms: "Confidentiality mismatch",
    result: "The public write is denied.",
    description:
      "A summary is still derived from the restricted report. A public destination does not satisfy the source’s confidentiality terms.",
    command: "bend examples/Flow.bend",
    outcome: "denied",
    icon: "×",
  },
  revoked: {
    code: "COMMIT / 03",
    destination: "Internal workspace",
    terms: "Capability removed before commit",
    result: "The revoked commit is denied.",
    description:
      "The final gate checks the live registry again. The revoked attempt preserves the held ledger and running session.",
    command: "bend examples/Commit.bend",
    outcome: "denied",
    icon: "×",
  },
};

const controls = document.querySelector(".scenario-controls");
controls.hidden = false;
controls.addEventListener("click", (event) => {
  const button = event.target.closest("button[data-scenario]");
  if (!button) return;
  const scenario = scenarios[button.dataset.scenario];
  if (!scenario) return;
  for (const item of controls.querySelectorAll("button")) {
    item.setAttribute("aria-pressed", String(item === button));
  }
  for (const field of [
    "code",
    "destination",
    "terms",
    "result",
    "description",
    "command",
  ]) {
    document.getElementById(`scenario-${field}`).textContent = scenario[field];
  }
  document.getElementById("scenario-outcome").dataset.outcome =
    scenario.outcome;
  document.getElementById("outcome-icon").textContent = scenario.icon;
});

const copy = document.getElementById("copy-command");
if (navigator.clipboard?.writeText) {
  copy.hidden = false;
  copy.addEventListener("click", async () => {
    const status = document.getElementById("copy-status");
    try {
      await navigator.clipboard.writeText(
        document.getElementById("quickstart").textContent,
      );
      status.textContent =
        "Commands copied. Install Bend 2.0.39 before running them.";
    } catch {
      status.textContent =
        "Clipboard unavailable. Select and copy the commands above.";
    }
  });
}
