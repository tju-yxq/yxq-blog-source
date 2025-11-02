# 表格和数学公式渲染修复说明

## 修复内容

### 1. 表格渲染优化

已创建自定义CSS文件 `static/css/custom-table-math.css`，确保:
- ✅ 所有表格都有清晰的边框
- ✅ 表头有灰色背景以便区分
- ✅ 奇偶行有不同背景色,提高可读性
- ✅ 鼠标悬停时有高亮效果
- ✅ 响应式设计,在移动设备上也能正常显示

### 2. 数学公式渲染配置

Hugo配置中已正确设置:
```toml
[markup.goldmark.extensions.passthrough]
  enable = true
  [markup.goldmark.extensions.passthrough.delimiters]
    block = [['\[', '\]'], ['$$', '$$']]
    inline = [['\(', '\)']]
```

支持的数学公式语法:
- **行内公式**: 使用 `\(` 和 `\)` 包裹,例如: `\(E = mc^2\)`
- **块级公式**: 使用 `$$` 包裹,例如:
  ```
  $$
  E = mc^2
  $$
  ```
  或使用 `\[` 和 `\]`:
  ```
  \[
  E = mc^2
  \]
  ```

### 3. KaTeX 渲染引擎

主题已集成KaTeX数学公式渲染引擎:
- 自动从CDN加载KaTeX CSS和字体
- 支持HTML和MathML双重输出格式
- 公式渲染质量高,性能好

## 使用说明

### 在Markdown中使用表格

```markdown
| 列1 | 列2 | 列3 |
| --- | --- | --- |
| 数据1 | 数据2 | 数据3 |
| 数据4 | 数据5 | 数据6 |
```

### 在Markdown中使用数学公式

#### 行内公式
```markdown
这是一个行内公式 \(E = mc^2\) 的示例。
```

#### 块级公式
```markdown
下面是一个复杂的公式:

$$
\text{FLOPs} = 2 \times B \times L \times D \times (44D + H \times L)
$$
```

或者:

```markdown
\[
\int_{a}^{b} f(x) dx = F(b) - F(a)
\]
```

### 注意事项

1. **表格**: 
   - 确保表格前后都有空行
   - 使用标准Markdown表格语法
   - 每列之间用 `|` 分隔

2. **数学公式**:
   - 块级公式(`$$`)前后需要空行
   - 使用LaTeX数学语法
   - 特殊符号需要转义

## 测试验证

启动Hugo服务器查看效果:
```bash
hugo server -D
```

然后访问: http://localhost:1313

检查以下内容:
- ✅ 表格是否有完整的边框
- ✅ 表头是否有灰色背景
- ✅ 数学公式是否正确渲染
- ✅ 行内公式和块级公式是否都能正常显示

## 已修改的文件

1. `static/css/custom-table-math.css` - 新创建的自定义CSS文件
2. `hugo.toml` - 添加了自定义CSS引用:
   ```toml
   custom_css = ["css/custom-table-math.css"]
   ```

## 如果还有问题

### 表格仍然没有边框
1. 清除浏览器缓存
2. 重启Hugo服务器
3. 检查浏览器开发者工具,确认CSS是否加载

### 数学公式不显示
1. 检查网络连接(KaTeX从CDN加载)
2. 查看浏览器控制台是否有错误
3. 确认公式语法是否正确
4. 尝试同时使用 `$$` 和 `\[ \]` 两种语法测试

### 构建时出现错误
如果Hugo构建时报告KaTeX错误,检查:
1. 公式语法是否有误
2. 特殊字符是否需要转义
3. 查看错误信息中指出的具体位置

## 进一步优化建议

1. **表格样式个性化**: 可以编辑 `static/css/custom-table-math.css` 调整:
   - 边框颜色
   - 表头背景色
   - 悬停效果颜色
   - 单元格内边距

2. **数学公式大小**: 在CSS中调整 `.katex` 的 `font-size` 属性

3. **移动端优化**: 如果表格在手机上显示不佳,可以考虑:
   - 使用更小的字体
   - 添加横向滚动
   - 简化复杂表格

## 参考资源

- [Hugo数学公式文档](https://gohugo.io/content-management/mathematics/)
- [KaTeX支持的函数](https://katex.org/docs/supported.html)
- [Markdown表格语法](https://www.markdownguide.org/extended-syntax/#tables)
