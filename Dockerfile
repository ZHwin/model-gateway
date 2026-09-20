FROM python:3.11-slim

LABEL maintainer="model-gateway"
WORKDIR /app

# 仅安装 Web 服务核心依赖（不含桌面 GUI 依赖，避免镜像臃肿/构建失败）
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 拷贝业务代码与模板
COPY app.py ./
COPY models_meta.json ./
COPY templates/ ./templates/

# 运行时数据目录（providers.json / config.json 等可挂载卷持久化）
RUN mkdir -p /data
ENV GATEWAY_DATA_DIR=/data \
    PYTHONUNBUFFERED=1 \
    PYTHONHASHSEED=0 \
    PYTHONDONTWRITEBYTECODE=1
VOLUME ["/data"]

EXPOSE 8000

# 健康检查（/health 为免鉴权端点）
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0) if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3).status==200 else sys.exit(1)"

# -OO: 去除 assert 和 docstring，降低常驻内存
# --limit-concurrency: 限制同时处理的请求数，避免突发流量打爆内存
# --timeout-keep-alive: 缩短 keep-alive，减少空闲连接驻留
CMD ["python", "-OO", "-m", "uvicorn", "app:app", \
     "--host", "0.0.0.0", "--port", "8000", \
     "--workers", "1", \
     "--limit-concurrency", "50", \
     "--timeout-keep-alive", "30"]
