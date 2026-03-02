#!/bin/bash
# Bedrock Proxy Docker 部署脚本

set -e

echo "🚀 Bedrock Effort Max Proxy - Docker 部署"
echo "=========================================="
echo

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "❌ 错误: Docker 未安装"
    echo "   请访问 https://docs.docker.com/get-docker/ 安装 Docker"
    exit 1
fi

# 检查 Docker Compose
if ! docker compose version &> /dev/null; then
    echo "❌ 错误: Docker Compose 未安装或版本过低"
    echo "   需要 Docker Compose v2.0+"
    exit 1
fi

# 检查是否已在运行
if docker ps --format '{{.Names}}' | grep -q '^bedrock-proxy$'; then
    echo "⚠️  容器已在运行"
    read -p "是否重启? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔄 重启容器..."
        docker compose restart
        echo "✅ 重启完成"
        exit 0
    else
        echo "ℹ️  使用现有容器"
        docker compose logs --tail=5 bedrock-proxy
        exit 0
    fi
fi

# 构建镜像
echo "📦 构建 Docker 镜像..."
docker compose build

echo
# 启动容器
echo "▶️  启动容器（后台运行，开机自动启动）..."
docker compose up -d

# 等待启动
echo "⏳ 等待服务就绪..."
for i in {1..10}; do
    if curl -s http://127.0.0.1:8888/health > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

echo
# 健康检查
echo "🔍 服务状态检查..."
HEALTH_DATA=$(curl -s http://127.0.0.1:8888/health 2>/dev/null)
CURL_EXIT=$?

if [ $CURL_EXIT -ne 0 ] || [ -z "$HEALTH_DATA" ]; then
    echo "❌ 健康检查失败 (exit code: $CURL_EXIT)"
    echo
    echo "📋 最近日志："
    docker compose logs --tail=30 bedrock-proxy
    echo
    echo "💡 故障排查："
    echo "   1. 检查端口是否被占用: lsof -i :8888"
    echo "   2. 查看完整日志: docker compose logs -f"
    echo "   3. 检查 AWS 凭证: ls -la ~/.aws/"
    echo "   4. 测试连接: curl -v http://127.0.0.1:8888/health"
    exit 1
fi

# 解析并显示状态
echo "$HEALTH_DATA" | jq -r '
  "✅ Proxy 启动成功！\n",
  "📊 服务信息:",
  "   地址: http://127.0.0.1:8888",
  "   区域: \(.region)",
  "   Cache: \(if .cache_enabled then "启用 (TTL: \(.cache_ttl))" else "禁用" end)",
  "   请求数: \(.requests_served)"
' 2>/dev/null || echo "✅ Proxy 启动成功！"

echo
echo "🐳 容器状态："
docker ps --filter name=bedrock-proxy --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo
RESTART_POLICY=$(docker inspect bedrock-proxy --format='{{.HostConfig.RestartPolicy.Name}}' 2>/dev/null)
if [ "$RESTART_POLICY" = "unless-stopped" ]; then
    echo "✅ 开机自动启动: 已启用"
else
    echo "⚠️  开机自动启动: $RESTART_POLICY"
fi

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Claude Code 配置说明"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "请编辑 Claude Code 配置文件:"
echo "  ~/.claude/settings.json"
echo
echo "添加以下配置（或参考 settings.json 示例）:"
echo
cat << 'EOF'
{
  "env": {
    // Bedrock 配置
    "CLAUDE_CODE_USE_BEDROCK": "1",
    "ANTHROPIC_BEDROCK_BASE_URL": "http://127.0.0.1:8888",
    "CLAUDE_CODE_SKIP_BEDROCK_AUTH": "1",
    "AWS_REGION": "ap-northeast-1",

    // 模型配置
    "ANTHROPIC_MODEL": "global.anthropic.claude-opus-4-6-v1[1m]",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "global.anthropic.claude-opus-4-6-v1[1m]",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "global.anthropic.claude-sonnet-4-6-v1[1m]",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "global.anthropic.claude-haiku-4-5-20251001-v1:0"
  }
}
EOF

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 常用命令"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  查看日志:  docker compose logs -f"
echo "  停止服务:  docker compose down"
echo "  重启服务:  docker compose restart"
echo "  健康检查:  curl http://127.0.0.1:8888/health | jq"
echo "  查看状态:  docker ps | grep bedrock-proxy"
echo
echo "📚 完整文档: README.md"
echo

# 显示实时日志（可选）
if [ -t 0 ]; then
    # 仅在交互式终端时询问
    read -p "是否查看实时日志? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo
        echo "📋 实时日志 (Ctrl+C 退出):"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        docker compose logs -f
    fi
fi

exit 0
