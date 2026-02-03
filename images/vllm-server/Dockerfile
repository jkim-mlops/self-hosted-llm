# Use official vLLM GPU image for better performance
FROM --platform=linux/amd64 vllm/vllm-openai:v0.6.1

# Set GPU-specific environment variables for optimal performance
ENV VLLM_ATTENTION_BACKEND=FLASH_ATTN
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128

EXPOSE 8000

WORKDIR /workspace

# Use vLLM's OpenAI-compatible server
ENTRYPOINT ["python3", "-m", "vllm.entrypoints.openai.api_server"]
CMD ["--host", "0.0.0.0", "--port", "8000", "--model", "/model", "--served-model-name", "Qwen/Qwen2.5-1.5B-Instruct", "--dtype", "bfloat16", "--max-model-len", "2048"]