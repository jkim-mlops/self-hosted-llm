FROM --platform=linux/amd64 continuumio/miniconda3:latest

WORKDIR /app

# Copy environment file
COPY environment.yml .

# Create conda environment
RUN conda env create -f environment.yml && \
    conda clean -afy

# Make RUN commands use the new environment
SHELL ["conda", "run", "-n", "chatbot", "/bin/bash", "-c"]

# Copy application code
COPY main.py .

# Expose Streamlit port
EXPOSE 8501

# Activate environment and run app
ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "chatbot"]
CMD ["streamlit", "run", "main.py", "--server.port=8501", "--server.address=0.0.0.0"]