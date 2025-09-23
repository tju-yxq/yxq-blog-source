# 设置脚本在遇到任何错误时立即退出。
set -e

# --- 脚本开始 ---
echo "🚀 Starting complete deployment process..."

# 允许用户传入一个自定义的提交信息作为参数。
MSG="$1"
if [ -z "$MSG" ]; then
  MSG="Build and deploy site at $(date)"
fi
echo "ℹ️ Commit message: $MSG"


# --- 第一步: 构建网站 ---
echo "\n[Step 1/4] Building the website with Hugo..."
hugo --cleanDestinationDir
echo "✅ Hugo build complete."


# --- 第二步: 更新搜索索引 ---
echo "\n[Step 2/4] Updating the Algolia search index..."
npm run algolia
echo "✅ Algolia index updated."


# --- 第三步: 部署生成的网站到 GitHub Pages ---
echo "\n[Step 3/4] Deploying website to GitHub Pages..."
# 进入 public 目录
cd public
# 添加所有文件
git add .
# 提交改动
git commit -m "$MSG"
# 推送到远程仓库
git push origin main
# 返回项目根目录
cd ..
echo "✅ Website deployed to GitHub Pages."


# --- 第四步: 备份源码 ---
echo "\n[Step 4/4] Backing up source code..."
git add .
git commit -m "$MSG"
git push origin main
echo "✅ Source code backed up."


# --- 脚本结束 ---
echo "\n🎉 Deployment process finished successfully!"
