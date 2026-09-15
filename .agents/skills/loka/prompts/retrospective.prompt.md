---
name: session-retrospective
version: 1.1.0
description: "Distills full conversation context into an objective technical post-mortem and prepends it directly to docs/retrospectives.md"
type: prompt-template
---

**PRIMARY DIRECTIVE**
Execute an in-depth "Session Retrospective." Evaluate the entire conversation strictly based on verifiable facts, translate it into a universal, objective technical report (Technical Post-Mortem style), and write/prepend this entry directly to `docs/retrospectives.md`. Do not output the retrospective body into the chat conversation.

**OUTPUT TARGET & FILE HANDLING**
- **Target File:** `docs/retrospectives.md`
- **Write Mode:** Prepend (Insert the new entry at the top of the file, directly beneath the main document title `# Session Retrospectives`).
- **File Initialization:** If `docs/retrospectives.md` does not exist:
  1. Create the `docs/` directory if missing.
  2. Initialize the file with `# Session Retrospectives\n\n`.
  3. Insert the retrospective entry immediately below the header.
- **Chat Suppression:** Do NOT output the retrospective content into the chat. Emit only a single status confirmation upon successful file write:
  `[SUCCESS] Retrospective recorded to docs/retrospectives.md (Timestamp: <ISO-8601 Timestamp>)`

**CONSTRAINTS & GROUNDING**
- Utilize only verifiable facts, explicit decisions, and concrete errors from the actual dialogue history (zero hallucinations or speculative fill).
- Absolute detachment: No conversational pleasantries, no first-person ("I/we") or second-person ("you") perspectives.
- Focus strictly on cause-and-effect relationships and reproducible technical insights.

**EXECUTION STEPS**
1. **Internal Evaluation:** Identify primary goals, friction points, invalidated assumptions, pivotal breakthroughs, and the finalized solution architecture.
2. **Context Abstraction:** Distill domain-specific knowledge into durable reference documentation.
3. **Format Entry:** Format the retrospective using the Entry Template defined below.
4. **File Prepend Operation:** Load `docs/retrospectives.md`, prepend the newly generated entry below the top-level title, and persist changes.

---

### ENTRY TEMPLATE (To prepend to `docs/retrospectives.md`)

```markdown
---

## Retrospective — [YYYY-MM-DD HH:MM UTC]

### 1. Initial State & Objectives
- **Primary Objective:** [Concise definition of the intended task]
- **Operational Constraints:** [Relevant technical constraints, tools, versions, environment parameters, or input data]

### 2. Process Dynamics & Friction Points
- **Execution Milestones:** [Chronological, bulleted breakdown of core actions taken]
- **Blockers & Invalid Assumptions:** [Which approaches failed and why? Specific error patterns or conceptual mistakes]
- **Breakthrough & Resolution:** [Exact methodological or technical adjustments that resolved the blockers]

### 3. Derived Paradigms & Best Practices
- **[Category/Domain]** *Condition / Failure Pattern* → **Directive:** *Concrete, imperative rule for future execution*
