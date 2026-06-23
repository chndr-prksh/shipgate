# ShipGate

Most AI features don't fail because the model is bad. They fail because nobody defined what *good enough to ship* meant — so a feature that looks fine on average accuracy goes out the door carrying a tail failure no one priced in. ShipGate is the small, opinionated tool a product manager uses to close that gap: it runs a labelled dataset through an AI feature, scores it against a quality bar **you** define, and returns one **GO / NO-GO** call with the reasons attached.

This repo demos it on an enterprise **support-triage decision agent** — given a ticket, the agent decides a *category*, a *priority*, and the *next action*. That's a representative agentic-decision surface (same shape as approvals, routing, moderation, or anywhere an agent acts under uncertainty), and it makes the lesson concrete.

## The thing to notice

The bundled demo agent **clears every aggregate quality gate** — category accuracy, priority, action accuracy, and drafted-response quality all sit above the bar. On an accuracy-only review, it ships.

But it fails to escalate **1 of 2 safety-critical tickets**, and escalation recall is a **hard gate** — a single miss blocks the release. ShipGate returns **NO-GO** and points at the exact ticket (`T-014`, an account-takeover report that gets mis-routed to the account queue instead of a human).

That's the entire argument for evaluation rigor on one screen: aggregate metrics hide tail failures, and the PM's job is to define the gate that catches them *before* users do.

See [`docs/sample_scorecard.html`](docs/sample_scorecard.html) for the rendered verdict.

## Quickstart

```bash
pip install -r requirements.txt
python -m shipgate.cli           
xdg-open reports/scorecard.html   
```

The command exits `0` on GO and `1` on NO-GO, so it drops straight into CI as a release gate.

## The quality bar (this is the product decision)

The bar lives in [`quality_bar.yaml`](quality_bar.yaml), not in code, because deciding what "good" means is a product call you should be able to tune without a pull request. Each gate compares a metric to a minimum and is either **soft** (a few misses tolerated) or **hard** (a single miss vetoes the release).

| Gate | Bar | Type | Why this bar |
|---|---|---|---|
| `category_accuracy` | ≥ 85% | soft | wrong queue wastes time but is recoverable |
| `priority_exact` | ≥ 75% | soft | off-by-one priority is usually fine |
| `action_accuracy` | ≥ 80% | soft | recommended next step matches the analyst's call |
| `response_quality_avg` | ≥ 3.5 / 5 | soft | drafted replies are reviewed before sending |
| `safety_escalation_recall` | = 100% | **hard** | every safety-critical ticket must reach a human |

**Ship rule:** GO only if all hard gates pass *and* soft-gate failures stay within `soft_gate_failures_allowed`.

## How it measures

Three dimensions are label-based and deterministic — did the agent pick the right category, priority, and action? Response quality has no single correct string, so it uses an **LLM-as-judge**: a separate model rates the drafted reply against a rubric (length, ownership/empathy, a concrete next step), and a reply attached to the *wrong* decision is penalised. To keep the repo runnable with zero API keys, the default judge is a deterministic heuristic standing in for the model. The harness also reports `priority_within_one` (how *close* the priority was) as an ungated signal, because "how wrong" matters, not just "wrong."

## Grade a real model

By default the agent is a deterministic stub — its job is to give the harness something to grade, and it is *intentionally flawed* (it checks for safety signals last) so the safety gate has something to catch. To point ShipGate at a real model instead:

```bash
pip install anthropic
export ANTHROPIC_API_KEY=...            
export SHIPGATE_USE_REAL_MODEL=1
export SHIPGATE_MODEL=claude-haiku-4-5  
python -m shipgate.cli
```

The agent and judge call-sites live in `shipgate/agent.py` and `shipgate/judges.py`; everything downstream — metrics, gates, scorecard — is unchanged.

## Layout

```
shipgate/
  agent.py       feature under test (stub + real-model hook)
  dataset.py     load + validate the golden set
  judges.py      response-quality judge (heuristic + LLM-as-judge)
  evaluator.py   run the agent, compute metrics
  decision.py    apply the quality bar -> GO / NO-GO
  report.py      render the HTML scorecard
  cli.py         entrypoint
data/golden_tickets.jsonl   18 labelled tickets (2 safety-critical)
quality_bar.yaml            the editable definition of "good"
docs/sample_scorecard.html  rendered example output
tests/                      pins the headline story + gate logic
```

## Tests

```bash
pytest -q
```

The suite locks in the demo's story (soft gates pass, safety gate fails → NO-GO) and the gate logic (hard-gate veto, soft-gate tolerance).

## Where this goes next

If this grew past a demo: expand the golden set and add inter-rater agreement on the labels; track metrics **per slice** (e.g. safety recall by ticket type), since a gate that's green overall can be red on the slice that matters; add cost and latency gates; and version the dataset so you can diff scorecards across model versions and catch regressions, not just read snapshots.

---

Built as a portfolio piece on eval-first AI product work. The harness is the point — the triage agent is a stand-in you can swap for any decision feature.
