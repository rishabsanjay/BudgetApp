from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
import pandas as pd
from typing import List, Dict
import json
from pathlib import Path

app = FastAPI(title="Budget App")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create uploads directory if it doesn't exist
UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

@app.post("/api/upload")
async def upload_file(file: UploadFile = File(...)):
    try:
        # Save the uploaded file
        file_path = UPLOAD_DIR / file.filename
        with open(file_path, "wb") as buffer:
            content = await file.read()
            buffer.write(content)
        
        # Read the file based on its extension
        if file.filename.endswith('.csv'):
            df = pd.read_csv(file_path)
        elif file.filename.endswith(('.xlsx', '.xls')):
            df = pd.read_excel(file_path)
        else:
            raise HTTPException(status_code=400, detail="Unsupported file format")
        
        # Convert DataFrame to list of dictionaries
        transactions = df.to_dict(orient='records')
        
        return JSONResponse(content={
            "message": "File uploaded successfully",
            "transactions": transactions
        })
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/health")
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 