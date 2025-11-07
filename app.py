# app.py
from fastapi import FastAPI
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer, util
import pandas as pd
import torch

app = FastAPI()

# Load model and data once
MODEL_PATH = "fine_tuned_fir_model"
DATA_PATH = "bns_mappings_triplet_seed.csv"

model = SentenceTransformer(MODEL_PATH)
df = pd.read_csv(DATA_PATH)

class FIRRequest(BaseModel):
    fir_text: str
    top_k: int = 3  # default

@app.post("/predict")
async def predict(request: FIRRequest):
    fir_input = request.fir_text
    top_k = request.top_k

    fir_embedding = model.encode(fir_input, convert_to_tensor=True)
    pos_embeddings = model.encode(df["positive_text"].tolist(), convert_to_tensor=True)
    cos_scores = util.cos_sim(fir_embedding, pos_embeddings)[0]

    top_results = torch.topk(cos_scores, k=len(df))
    seen_sections = set()
    results = []

    for score, idx in zip(top_results[0], top_results[1]):
        i = int(idx)
        section_id = df.iloc[i]['positive_id']
        if section_id not in seen_sections:
            seen_sections.add(section_id)
            results.append({
                "section_id": int(section_id),
                "section_text": str(df.iloc[i]['positive_text']),
                "similarity": float(score)
            })
        if len(results) >= top_k:
            break

    return {"results": results}
