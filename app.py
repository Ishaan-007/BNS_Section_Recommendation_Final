# app.py
import os
import re
import json
import logging
import asyncio
import pandas as pd
from functools import partial
from typing import List, Optional
from pydantic import BaseModel
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sentence_transformers import SentenceTransformer, util
import torch

# Optional Groq XAI
try:
    from groq import Groq
    _GROQ_AVAILABLE = True
except Exception:
    _GROQ_AVAILABLE = False

# Basic logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("bns_backend")

app = FastAPI(title="FIR → BNS Recommender")

# CORS - permit all origins by default (change as needed)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Config (adjust as needed or use environment variables)
MODEL_PATH = os.getenv("MODEL_PATH", "fine_tuned_fir_model")  # local fine-tuned model
DATA_PATH = os.getenv("DATA_PATH", "bns_mappings_triplet_seed.csv")
# GROQ API key (optional) - set as environment variable if you want trigger phrases
GROQ_API_KEY = os.getenv("GROQ_API_KEY", None)

# ----- Helpful text normalization/token helpers -----
from sklearn.feature_extraction.text import ENGLISH_STOP_WORDS


def normalize(text: Optional[str]) -> str:
    if text is None:
        return ""
    text = str(text).lower()
    text = text.replace("’", "'").replace("“", '"').replace("”", '"').replace("—", " ")
    text = re.sub(r"[^\w\s']", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def tokens(text: Optional[str]) -> List[str]:
    t = normalize(text).split()
    return [tok for tok in t if tok not in ENGLISH_STOP_WORDS and len(tok) > 1]


# ----- Pydantic request model -----
class FIRRequest(BaseModel):
    fir_text: str
    top_k: int = 3


# ----- Load model + data at startup -----
logger.info("Loading model and data...")
try:
    model = SentenceTransformer(MODEL_PATH)
    logger.info(f"Loaded SentenceTransformer from {MODEL_PATH}")
except Exception:
    logger.exception("Failed to load fine-tuned model. Attempting to load default 'all-MiniLM-L6-v2'.")
    model = SentenceTransformer("all-MiniLM-L6-v2")
    logger.info("Loaded fallback model 'all-MiniLM-L6-v2'")

# Load DataFrame
if not os.path.exists(DATA_PATH):
    logger.error(f"DATA_PATH not found: {DATA_PATH}")
    raise FileNotFoundError(f"Could not find data file: {DATA_PATH}")

df = pd.read_csv(DATA_PATH, encoding="utf-8", low_memory=False)
df = df.dropna(subset=["positive_text", "positive_id"]).reset_index(drop=True)
logger.info(f"Loaded dataset with {len(df)} rows from {DATA_PATH}")

# Precompute positive texts, ids and embeddings
pos_texts = df["positive_text"].astype(str).tolist()
pos_ids = df["positive_id"].tolist()

logger.info("Encoding positive_texts to embeddings (precompute). This may take a while...")
pos_embeddings = model.encode(pos_texts, convert_to_tensor=True)
logger.info("Precomputed embeddings for all positive_texts.")


# ----- Utilities for robust JSON extraction from model output -----
def _extract_first_balanced_array(text: str) -> Optional[str]:
    """
    Find the first balanced JSON array in `text` by scanning for '[' and matching closing ']'.
    Returns the substring including brackets if found, else None.
    """
    start = text.find('[')
    if start == -1:
        return None
    stack = 0
    for i in range(start, len(text)):
        ch = text[i]
        if ch == '[':
            stack += 1
        elif ch == ']':
            stack -= 1
            if stack == 0:
                return text[start:i + 1]
    return None


def _clean_candidate_json(candidate: str) -> str:
    """
    Lightweight cleanup:
    - Replace smart quotes with straight quotes
    - Remove trailing commas before closing brackets
    """
    s = candidate
    # normalize quotation marks
    s = s.replace("“", '"').replace("”", '"').replace("’", "'").replace("`", "'")
    # remove trailing commas before closing brackets/objects
    s = re.sub(r",\s*]", "]", s)
    s = re.sub(r",\s*}", "}", s)
    return s


def _extract_quoted_phrases_fallback(raw: str, max_phrases: int = 10) -> List[str]:
    """
    As a last resort, grab quoted substrings from the raw response and return them as phrases.
    This is not ideal but better than returning parser error strings.
    """
    # capture double-quoted then single-quoted strings (prefer double first)
    dq = re.findall(r'"([^"]{2,}?)"', raw)
    sq = re.findall(r"'([^']{2,}?)'", raw)
    combined = []
    for q in dq + sq:
        # simple cleanup
        phrase = q.strip()
        if phrase and phrase not in combined:
            combined.append(phrase)
        if len(combined) >= max_phrases:
            break
    return combined


# ----- Groq trigger extractor (runs in executor to avoid blocking) -----
def _get_trigger_phrases_groq_sync(fir_text: str, section_text: str, api_key: str, max_phrases: int = 10) -> List[str]:
    """
    Synchronous call to Groq SDK. Returns list of phrases (strings).
    Designed to be run in a thread pool via run_in_executor.
    This function is robust to extra non-JSON commentary in the model output.
    """
    if not _GROQ_AVAILABLE:
        logger.debug("Groq SDK not installed; returning empty triggers.")
        return []

    if not api_key:
        logger.debug("GROQ_API_KEY not set; returning empty triggers.")
        return []

    try:
        client = Groq(api_key=api_key)
    except Exception as e:
        logger.exception("Failed to create Groq client")
        return []

    prompt = f"""
You are a very precise information extractor (legal domain). Given an FIR (police report) sentence/paragraph and a recommended BNS (Bharatiya Nyaya Sanhita) section description, your job is to return ONLY a JSON array of phrases (strings) that appear verbatim or very close to verbatim in the FIR and that plausibly trigger the mapping to the given section.

Rules:
1) Output MUST be a single, valid JSON array of strings and nothing else. Example: ["phrase1","phrase2"]
2) Each string must be a contiguous substring from the FIR text (verbatim or minor punctuation/whitespace differences).
3) Prefer longer multi-word phrases.
4) If nothing useful is found, return [].
5) Return at most {max_phrases} items, ordered by relevance.

FIR:
\"\"\"{fir_text}\"\"\"


BNS Section:
\"\"\"{section_text}\"\"\"


Output:
"""

    try:
        response = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.0,
            max_tokens=512
        )
        raw = response.choices[0].message.content.strip()
        logger.debug(f"Raw Groq output: {raw[:1000]}")

        # 1) Try direct JSON parse
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, list):
                # ensure strings and limit size
                return [str(x) for x in parsed[:max_phrases]]
        except Exception:
            pass

        # 2) Extract first balanced array substring and try parsing that
        candidate = _extract_first_balanced_array(raw)
        if candidate:
            candidate_clean = _clean_candidate_json(candidate)
            try:
                parsed = json.loads(candidate_clean)
                if isinstance(parsed, list):
                    return [str(x) for x in parsed[:max_phrases]]
            except Exception:
                # attempt further cleaning: remove stray unescaped quotes or trailing commentary using regex
                candidate_clean2 = re.sub(r'(?<!\\)\"\"\"', '"', candidate_clean)  # remove triple quotes
                candidate_clean2 = re.sub(r'\s*\(\s*.*?example.*?\)\s*', '', candidate_clean2, flags=re.IGNORECASE)
                candidate_clean2 = re.sub(r'\n+', ' ', candidate_clean2)
                candidate_clean2 = _clean_candidate_json(candidate_clean2)
                try:
                    parsed = json.loads(candidate_clean2)
                    if isinstance(parsed, list):
                        return [str(x) for x in parsed[:max_phrases]]
                except Exception:
                    logger.debug("Failed to parse cleaned candidate JSON array.")

        # 3) Remove common non-JSON text and try to salvage with simple replacements
        fallback_candidate = raw
        fallback_candidate = fallback_candidate.replace("’", "'").replace("“", '"').replace("”", '"')
        fallback_candidate = re.sub(r'(?m)^\s*output[:\-]*', '', fallback_candidate, flags=re.IGNORECASE)
        fallback_candidate = _clean_candidate_json(fallback_candidate)
        # try to find any array now
        candidate2 = _extract_first_balanced_array(fallback_candidate)
        if candidate2:
            try:
                parsed = json.loads(candidate2)
                if isinstance(parsed, list):
                    return [str(x) for x in parsed[:max_phrases]]
            except Exception:
                logger.debug("Failed to parse candidate2 after additional cleaning.")

        # 4) As a last fallback, extract plausible quoted phrases
        quoted = _extract_quoted_phrases_fallback(raw, max_phrases=max_phrases)
        if quoted:
            return quoted

        # 5) If nothing found, return empty list (stable shape)
        logger.warning("Groq output could not be parsed into a clean phrase list; returning empty triggers.")
        return []
    except Exception as e:
        logger.exception("Groq extraction failed")
        return []


async def get_trigger_phrases_async(fir_text: str, section_text: str, api_key: str, max_phrases: int = 10) -> List[str]:
    """
    Async wrapper that runs the sync Groq call in a thread executor.
    """
    if not _GROQ_AVAILABLE or not api_key:
        return []
    loop = asyncio.get_running_loop()
    func = partial(_get_trigger_phrases_groq_sync, fir_text, section_text, api_key, max_phrases)
    return await loop.run_in_executor(None, func)


# ----- Prediction endpoint -----
@app.post("/predict")
async def predict(request: FIRRequest):
    fir_input = request.fir_text
    top_k = max(1, int(request.top_k))

    if not fir_input or not fir_input.strip():
        raise HTTPException(status_code=400, detail="fir_text is empty")

    # Encode FIR and compute cosine similarities
    try:
        fir_embedding = model.encode(fir_input, convert_to_tensor=True)
        cos_scores = util.cos_sim(fir_embedding, pos_embeddings)[0]  # tensor of shape (n_pos,)
    except Exception:
        logger.exception("Model encoding failed")
        raise HTTPException(status_code=500, detail="Model encoding error")

    # Get sorted indices (highest to lowest)
    try:
        topk = torch.topk(cos_scores, k=len(cos_scores))
    except Exception:
        # Fallback to cpu sort if topk fails
        values = cos_scores.cpu().detach().numpy()
        order = values.argsort()[::-1]
        topk_indices = order
        topk_values = values[order]
    else:
        topk_values = topk.values
        topk_indices = topk.indices

    seen_sections = set()
    results = []

    # We'll collect candidates first (max up to len(df)), then keep first unique top_k by section id
    for score_tensor, idx_tensor in zip(topk_values, topk_indices):
        i = int(idx_tensor)
        section_id = df.iloc[i]["positive_id"]
        if section_id in seen_sections:
            continue
        seen_sections.add(section_id)

        score = float(score_tensor.cpu().detach().item()) if hasattr(score_tensor, "cpu") else float(score_tensor)

        results.append({
            "section_id": int(section_id),
            "section_text": str(df.iloc[i]["positive_text"]),
            "similarity": score
        })

        if len(results) >= top_k:
            break

    # Optionally add trigger phrases using Groq (async, in parallel)
    if GROQ_API_KEY and _GROQ_AVAILABLE:
        tasks = []
        for r in results:
            tasks.append(get_trigger_phrases_async(fir_input, r["section_text"], GROQ_API_KEY, max_phrases=8))
        try:
            triggers_lists = await asyncio.gather(*tasks)
        except Exception:
            logger.exception("Groq gather failed")
            triggers_lists = [[] for _ in results]
        for r, triggers in zip(results, triggers_lists):
            # ensure triggers is list of strings
            if isinstance(triggers, list):
                r["triggers"] = [str(t) for t in triggers][:8]
            else:
                r["triggers"] = []
    else:
        for r in results:
            r["triggers"] = []

    return {"results": results}
