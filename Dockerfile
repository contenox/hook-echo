FROM python:3.12-slim

WORKDIR /app

# Copy only the dependency definition file first for better layer caching
COPY pyproject.toml .

# Install the package and its dependencies
RUN pip install .

# Copy the rest of the application code
COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
