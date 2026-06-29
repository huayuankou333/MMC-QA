"""MMC-QA: a natively sourced multilingual and multicultural QA benchmark.

Pipeline modules:
    mmc_qa.generate  - stage 1: produce model answers
    mmc_qa.judge     - stage 2: LLM-judge answers for correctness
    mmc_qa.score     - stage 3: compute CO/NA/IN/CGA/F-score metrics

Shared helpers:
    mmc_qa.data        - load the benchmark (local JSONL or Hugging Face Hub)
    mmc_qa.llm_client  - OpenAI-compatible client for models and the judge
"""

__version__ = "0.1.0"
