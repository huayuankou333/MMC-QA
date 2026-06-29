# MMC-QA

**A Natively Sourced Multilingual and Multicultural Question Answering Benchmark**

MMC-QA is a benchmark of **1,064 natively sourced questions** spanning **11 language
groups**, **5 cultural dimensions**, and three difficulty tiers. Unlike translated
benchmarks (e.g., translating MMLU), every question is grounded in *locally
sourced* cultural knowledge, so a model cannot succeed by transferring
English-centric knowledge across languages. The benchmark is designed to expose
the **Illusion of Cultural Alignment**: multilingual fluency is routinely
mistaken for genuine multicultural competence.

This repository contains the **dataset** and the **evaluation toolkit** used in
the paper: a clean, three-stage pipeline to reproduce our numbers or evaluate
your own models.

- 📄 Paper: *MMC-QA: A Natively Sourced Multilingual and Multicultural Question Answering Benchmark*
- 💻 Code: <https://github.com/huayuankou333/MMC-QA>
- 🌐 Project website: <https://huayuankou333.github.io/MMC-QA>
- 🤗 Dataset: <https://huggingface.co/datasets/m-a-p/MMC-QA>

---

## What's in the benchmark

| Axis | Coverage |
|------|----------|
| **Languages (11)** | English, Chinese, Portuguese, Thai, Russian, Korean, French, Japanese, Malay, Indonesian, Spanish |
| **Cultural dimensions (5)** | History and Collective Memory · Beliefs, Values, and Knowledge Systems · Social Norms and Customs · Language Expression and Communication Arts · Cultural Products and Symbols |
| **Size** | 1,064 items, each with a single verifiable answer |

Each item is **white-box** (objective, single-answer) so it can be scored
automatically by an LLM judge. See [`data/README.md`](data/README.md) for the
full dataset card and field schema.

---

## Installation

```bash
git clone https://github.com/huayuankou333/MMC-QA.git
cd MMC-QA
python -m venv .venv && source .venv/bin/activate
pip install -e .            # installs the mmc_qa package + CLIs
# optional, to stream the dataset from the Hugging Face Hub:
pip install -e ".[hub]"
```

Requires Python ≥ 3.9.

---

## Step 1 — Get the dataset

The first step is always to obtain the data. Two options:

**A. Download from the Hugging Face Hub** (recommended)

```bash
# As files:
huggingface-cli download m-a-p/MMC-QA --repo-type dataset --local-dir data
# ...or directly in Python (pip install datasets):
python -c "from datasets import load_dataset; load_dataset('m-a-p/MMC-QA', split='test')"
```

**B. Use the copy shipped in this repo**

A ready-to-use copy lives at [`data/mmc_qa.jsonl`](data/mmc_qa.jsonl) (and
`data/mmc_qa.csv`). All commands below default to this local file via
`--data data/mmc_qa.jsonl`. Omitting `--data` makes the tools pull from the Hub
instead.

Each line of `mmc_qa.jsonl` looks like:

```json
{
  "id": "PT-01",
  "language": "pt-PT",
  "culture_circle": "Portuguese",
  "category": "History and Collective Memory",
  "question": "Em que ano foi fundada a cidade de Lisboa?",
  "answer": "...",
  "question_zh": "...",
  "answer_zh": "...",
  "source_url": "https://...",
  "source_url_desc": "..."
}
```

---

## Step 2 — Configure API access

All three stages talk to models through an **OpenAI-compatible** chat endpoint
(most providers expose one). Configure credentials via environment variables —
**no keys live in the code**:

```bash
export MMCQA_API_KEY="sk-..."                       # key for the models under test
export MMCQA_BASE_URL="https://api.openai.com/v1"   # any OpenAI-compatible gateway

# Optional: run the LLM judge on a separate gateway
export MMCQA_JUDGE_API_KEY="..."
export MMCQA_JUDGE_BASE_URL="https://generativelanguage.googleapis.com/v1beta/openai"
```

`GEMINI_API_KEY` / `GEMINI_BASE_URL` and `OPENAI_API_KEY` / `OPENAI_BASE_URL`
are also honored for convenience.

---

## Step 3 — Run the evaluation pipeline

The toolkit is three stages: **generate → judge → score**. Each stage reads and
writes JSONL and is fully resumable (re-run to continue after an interruption).

### 3.1 Generate answers

```bash
python -m mmc_qa.generate \
    --data data/mmc_qa.jsonl \
    --model gpt-5.2 \
    --output runs/gpt-5.2.jsonl \
    --workers 8
```

Useful flags: `--language pt-PT` (evaluate one language), `--runs 5` (sample each
question 5× for the stability / Best-of-N analyses), `--temperature`, `--max-tokens`.

### 3.2 Judge answers for correctness

An LLM judge compares each answer to the gold answer and returns Yes/No.

```bash
python -m mmc_qa.judge \
    --responses runs/gpt-5.2.jsonl \
    --judge-model gemini-3.1-pro \
    --output runs/gpt-5.2.judged.jsonl \
    --workers 8
```

### 3.3 Score (CO / NA / IN / CGA / F-score)

```bash
python -m mmc_qa.score \
    --judged runs/gpt-5.2.judged.jsonl \
    --judge-model gemini-3.1-pro \
    --output runs/gpt-5.2.metrics
```

This writes `*.csv` (overall), `*.per_language.csv`, `*.per_category.csv`, and
`*.json`. To score several models together, concatenate their judged JSONL files
and pass the combined file.

**Metrics** (SimpleQA-style):

| Metric | Definition |
|--------|------------|
| **CO**  | correct answers / all answers |
| **NA**  | not-attempted (refusal, hedging, no concrete claim) / all answers |
| **IN**  | incorrect concrete answers / all answers |
| **CGA** | CO / (CO + IN) — correct given attempted |
| **F**   | harmonic mean of CO and CGA — the headline score |

Wrong answers are split into NA vs IN by a second LLM pass (on by default;
decisions are cached). Pass `--no-rejudge` for a quick, API-free run that counts
every wrong answer as IN (then F == CO).

---

## Reproducing the paper's analyses

- **Locality Effect / main table** — run stages 3.1–3.3 for each model and read
  the per-language and per-category CSVs.
- **Competence Illusion (Best/Worst-of-N)** — generate with `--runs 5` (or more),
  then aggregate best/worst correct across runs per question.
- **Confidence Illusion (calibration / ECE)** — see
  [`advanced/calibration_eval.py`](advanced/calibration_eval.py). It judges
  confidence-annotated outputs and emits `task1_model_summary.csv` (per-model ECE)
  and `task1_bucket_summary.csv` (accuracy by confidence bucket).

---

## Repository layout

```
MMC-QA/
├── data/
│   ├── mmc_qa.jsonl          # the benchmark (1,064 items)
│   ├── mmc_qa.csv
│   └── README.md             # dataset card + field schema
├── src/mmc_qa/
│   ├── data.py               # dataset loader (local JSONL or HF Hub)
│   ├── llm_client.py         # OpenAI-compatible client (models + judge)
│   ├── generate.py           # stage 1
│   ├── judge.py              # stage 2
│   └── score.py              # stage 3
├── advanced/
│   └── calibration_eval.py   # confidence-calibration (ECE) reproduction
├── tools/
│   └── build_dataset.py      # how the public dataset was built from source
├── examples/run_pipeline.sh  # end-to-end example
├── requirements.txt
└── pyproject.toml
```

---

## Citation

```bibtex
@article{mmcqa,
  title  = {MMC-QA: A Natively Sourced Multilingual and Multicultural Question Answering Benchmark},
  author = {Chen, Xianru and Huang, Yukai and Chen, Mingxiang and Lei, Xinping and
            Deng, Fangbing and Chen, Jin and Zhang, Ge and Huang, Wenhao and Liu, Jiaheng},
  year   = {2026}
}
```

## License

Code is released under the MIT License (see [`LICENSE`](LICENSE)). The dataset is
released under **CC BY 4.0** — see [`data/README.md`](data/README.md). Please
respect the terms of the original cited sources for individual items.
