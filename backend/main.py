from fastapi import FastAPI

app = FastAPI(title="SahaySetu API")


@app.get("/")
def root():
    return {"message": "SahaySetu Backend is running!"}