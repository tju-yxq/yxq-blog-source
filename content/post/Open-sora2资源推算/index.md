---
title:       "MMDiT计算负载和访存分析"
subtitle:    ""
layout:      "single"
description: "MMDiT详细过程"
date:        2025-11-01
author:      "小段子"
image:       "/img/home-bg-jeep.jpg"
tags:        ["科研"]
categories:  ["科研"]
---

## 模型参数定义

| 参数符号 | 含义                             | 典型值 |
| -------- | -------------------------------- | ------ |
| B        | Batch Size                       | -      |
| L_img    | 图像序列长度                     | -      |
| L_txt    | 文本序列长度                     | -      |
| L        | 总序列长度 (L_txt + L_img)       | -      |
| D        | Hidden Size (隐藏层维度)         | 3072   |
| H        | Number of Heads (注意力头数)     | 24     |
| d        | Head Dimension (D / H)           | 128    |
| N_double | Double Stream Block 层数         | 19     |
| N_single | Single Stream Block 层数         | 38     |
| r_mlp    | MLP Ratio                        | 4.0    |
| D_mlp    | MLP Hidden Dimension (D × r_mlp) | 12288  |
| C_in     | 输入通道数                       | -      |
| C_out    | 输出通道数                       | -      |
| P        | Patch Size                       | 2      |
| D_vec    | Vector Input Dimension           | -      |
| D_ctx    | Context Input Dimension          | -      |

---

## 一、输入预处理阶段 (prepare_block_inputs)

### 1.1 图像输入投影 (img_in)

**操作**: Linear(C_in, D)

| 阶段         | 操作   | 计算负载 (FLOPs)                                   | 内存访问 (Bytes)                                             |
| ------------ | ------ | -------------------------------------------------- | ------------------------------------------------------------ |
| 图像输入投影 | Linear | $2 \times B \times L_{img} \times C_{in} \times D$ | $B \times L_{img} \times (C_{in} + D) \times 4 + (C_{in} \times D + D) \times 4$ |

**说明**:

- 矩阵乘法: $(B \times L_{img}, C_{in}) \times (C_{in}, D) = (B \times L_{img}, D)$
- FLOPs = 2 × M × N × K (矩阵乘法公式,M=B×L_img, N=D, K=C_in)
- 内存访问包括: 输入 + 输出 + 权重 + 偏置

### 1.2 条件输入投影 (cond_in, 可选)

**操作**: Linear(C_in + P², D)

| 阶段         | 操作   | 计算负载 (FLOPs)                                           | 内存访问 (Bytes)                                             |
| ------------ | ------ | ---------------------------------------------------------- | ------------------------------------------------------------ |
| 条件输入投影 | Linear | $2 \times B \times L_{img} \times (C_{in} + P^2) \times D$ | $B \times L_{img} \times (C_{in} + P^2 + D) \times 4 + ((C_{in} + P^2) \times D + D) \times 4$ |

### 1.3 时间步嵌入 (time_in)

**操作**: timestep_embedding → MLPEmbedder

#### 1.3.1 Timestep Embedding

| 阶段                 | 操作          | 计算负载 (FLOPs)        | 内存访问 (Bytes)        |
| -------------------- | ------------- | ----------------------- | ----------------------- |
| Sinusoidal Embedding | Trigonometric | $B \times 256 \times 4$ | $B \times 256 \times 4$ |

**说明**: 

- 包括 cos、sin、exp 计算
- 输出维度固定为 256

#### 1.3.2 MLPEmbedder (time_in)

**操作**: Linear(256, D) → SiLU → Linear(D, D)

| 阶段       | 操作        | 计算负载 (FLOPs)                 | 内存访问 (Bytes)                                            |
| ---------- | ----------- | -------------------------------- | ----------------------------------------------------------- |
| MLP 第一层 | Linear      | $2 \times B \times 256 \times D$ | $B \times (256 + D) \times 4 + (256 \times D + D) \times 4$ |
| SiLU 激活  | Elementwise | $B \times D \times 3$            | $B \times D \times 4 \times 2$                              |
| MLP 第二层 | Linear      | $2 \times B \times D \times D$   | $B \times (D + D) \times 4 + (D \times D + D) \times 4$     |

### 1.4 向量输入投影 (vector_in)

**操作**: MLPEmbedder(D_vec, D)

| 阶段       | 操作        | 计算负载 (FLOPs)                     | 内存访问 (Bytes)                                             |
| ---------- | ----------- | ------------------------------------ | ------------------------------------------------------------ |
| MLP 第一层 | Linear      | $2 \times B \times D_{vec} \times D$ | $B \times (D_{vec} + D) \times 4 + (D_{vec} \times D + D) \times 4$ |
| SiLU 激活  | Elementwise | $B \times D \times 3$                | $B \times D \times 4 \times 2$                               |
| MLP 第二层 | Linear      | $2 \times B \times D \times D$       | $B \times (D + D) \times 4 + (D \times D + D) \times 4$      |

### 1.5 引导强度嵌入 (guidance_in, 可选)

**操作**: MLPEmbedder(256, D)

| 阶段               | 操作          | 计算负载 (FLOPs)                 | 内存访问 (Bytes)                                            |
| ------------------ | ------------- | -------------------------------- | ----------------------------------------------------------- |
| Timestep Embedding | Trigonometric | $B \times 256 \times 4$          | $B \times 256 \times 4$                                     |
| MLP 第一层         | Linear        | $2 \times B \times 256 \times D$ | $B \times (256 + D) \times 4 + (256 \times D + D) \times 4$ |
| SiLU 激活          | Elementwise   | $B \times D \times 3$            | $B \times D \times 4 \times 2$                              |
| MLP 第二层         | Linear        | $2 \times B \times D \times D$   | $B \times (D + D) \times 4 + (D \times D + D) \times 4$     |

### 1.6 文本输入投影 (txt_in)

**操作**: Linear(D_ctx, D)

| 阶段     | 操作   | 计算负载 (FLOPs)                                    | 内存访问 (Bytes)                                             |
| -------- | ------ | --------------------------------------------------- | ------------------------------------------------------------ |
| 文本投影 | Linear | $2 \times B \times L_{txt} \times D_{ctx} \times D$ | $B \times L_{txt} \times (D_{ctx} + D) \times 4 + (D_{ctx} \times D + D) \times 4$ |

### 1.7 位置编码 (pe_embedder)

**操作**: EmbedND 或 LigerEmbedND

#### 1.7.1 标准 RoPE (EmbedND)

| 阶段      | 操作                      | 计算负载 (FLOPs)                               | 内存访问 (Bytes)                        |
| --------- | ------------------------- | ---------------------------------------------- | --------------------------------------- |
| RoPE 计算 | Trigonometric + Rearrange | $B \times L \times d \times n_{axes} \times 8$ | $B \times L \times d \times 4 \times 2$ |

**说明**:

- n_axes: 位置编码的轴数量 (通常为3: T, H, W)
- 包含 cos、sin 和张量重排操作

#### 1.7.2 Liger RoPE (LigerEmbedND)

| 阶段      | 操作          | 计算负载 (FLOPs)                               | 内存访问 (Bytes)                        |
| --------- | ------------- | ---------------------------------------------- | --------------------------------------- |
| RoPE 计算 | Trigonometric | $B \times L \times d \times n_{axes} \times 6$ | $B \times L \times d \times 4 \times 2$ |

---

## 二、Double Stream Block (N_double 层)

Double Stream Block 分别处理图像流和文本流,但共享位置编码。

### 2.1 Modulation (img_mod 和 txt_mod)

**操作**: SiLU → Linear(D, 6×D)

| 阶段         | 操作        | 计算负载 (FLOPs)                | 内存访问 (Bytes)                                           |
| ------------ | ----------- | ------------------------------- | ---------------------------------------------------------- |
| SiLU 激活    | Elementwise | $B \times D \times 3$           | $B \times D \times 4 \times 2$                             |
| Linear (img) | Linear      | $2 \times B \times D \times 6D$ | $B \times (D + 6D) \times 4 + (D \times 6D + 6D) \times 4$ |
| Linear (txt) | Linear      | $2 \times B \times D \times 6D$ | $B \times (D + 6D) \times 4 + (D \times 6D + 6D) \times 4$ |

**说明**: 输出 6 个调制参数: shift₁, scale₁, gate₁, shift₂, scale₂, gate₂

### 2.2 图像流 - 注意力准备

#### 2.2.1 LayerNorm + Modulation

| 阶段                | 操作          | 计算负载 (FLOPs)                     | 内存访问 (Bytes)                              |
| ------------------- | ------------- | ------------------------------------ | --------------------------------------------- |
| LayerNorm (img)     | Normalization | $B \times L_{img} \times D \times 5$ | $B \times L_{img} \times D \times 4 \times 3$ |
| Scale + Shift (img) | Elementwise   | $B \times L_{img} \times D \times 2$ | $B \times L_{img} \times D \times 4 \times 2$ |

#### 2.2.2 QKV 投影 (Fused 模式)

**操作**: Linear(D, 3×D)

| 阶段           | 操作   | 计算负载 (FLOPs)                               | 内存访问 (Bytes)                                             |
| -------------- | ------ | ---------------------------------------------- | ------------------------------------------------------------ |
| QKV 投影 (img) | Linear | $2 \times B \times L_{img} \times D \times 3D$ | $B \times L_{img} \times (D + 3D) \times 4 + (D \times 3D + 3D) \times 4$ |
| Rearrange      | Memory | $0$                                            | $B \times L_{img} \times 3D \times 4$                        |

#### 2.2.3 QKV 投影 (非 Fused 模式)

| 阶段         | 操作   | 计算负载 (FLOPs)                              | 内存访问 (Bytes)                                             |
| ------------ | ------ | --------------------------------------------- | ------------------------------------------------------------ |
| Q 投影 (img) | Linear | $2 \times B \times L_{img} \times D \times D$ | $B \times L_{img} \times 2D \times 4 + (D \times D + D) \times 4$ |
| K 投影 (img) | Linear | $2 \times B \times L_{img} \times D \times D$ | $B \times L_{img} \times 2D \times 4 + (D \times D + D) \times 4$ |
| V 投影 (img) | Linear | $2 \times B \times L_{img} \times D \times D$ | $B \times L_{img} \times 2D \times 4 + (D \times D + D) \times 4$ |

#### 2.2.4 QK Normalization

**操作**: RMSNorm (Fused)

| 阶段         | 操作    | 计算负载 (FLOPs)                              | 内存访问 (Bytes)                                       |
| ------------ | ------- | --------------------------------------------- | ------------------------------------------------------ |
| Q Norm (img) | RMSNorm | $B \times H \times L_{img} \times d \times 4$ | $B \times H \times L_{img} \times d \times 4 \times 2$ |
| K Norm (img) | RMSNorm | $B \times H \times L_{img} \times d \times 4$ | $B \times H \times L_{img} \times d \times 4 \times 2$ |

**说明**: RMSNorm 包括平方、均值、rsqrt、缩放操作

### 2.3 文本流 - 注意力准备

#### 2.3.1 LayerNorm + Modulation

| 阶段                | 操作          | 计算负载 (FLOPs)                     | 内存访问 (Bytes)                              |
| ------------------- | ------------- | ------------------------------------ | --------------------------------------------- |
| LayerNorm (txt)     | Normalization | $B \times L_{txt} \times D \times 5$ | $B \times L_{txt} \times D \times 4 \times 3$ |
| Scale + Shift (txt) | Elementwise   | $B \times L_{txt} \times D \times 2$ | $B \times L_{txt} \times D \times 4 \times 2$ |

#### 2.3.2 QKV 投影 (Fused 模式)

| 阶段           | 操作   | 计算负载 (FLOPs)                               | 内存访问 (Bytes)                                             |
| -------------- | ------ | ---------------------------------------------- | ------------------------------------------------------------ |
| QKV 投影 (txt) | Linear | $2 \times B \times L_{txt} \times D \times 3D$ | $B \times L_{txt} \times (D + 3D) \times 4 + (D \times 3D + 3D) \times 4$ |
| Rearrange      | Memory | $0$                                            | $B \times L_{txt} \times 3D \times 4$                        |

#### 2.3.3 QKV 投影 (非 Fused 模式)

| 阶段         | 操作   | 计算负载 (FLOPs)                              | 内存访问 (Bytes)                                             |
| ------------ | ------ | --------------------------------------------- | ------------------------------------------------------------ |
| Q 投影 (txt) | Linear | $2 \times B \times L_{txt} \times D \times D$ | $B \times L_{txt} \times 2D \times 4 + (D \times D + D) \times 4$ |
| K 投影 (txt) | Linear | $2 \times B \times L_{txt} \times D \times D$ | $B \times L_{txt} \times 2D \times 4 + (D \times D + D) \times 4$ |
| V 投影 (txt) | Linear | $2 \times B \times L_{txt} \times D \times D$ | $B \times L_{txt} \times 2D \times 4 + (D \times D + D) \times 4$ |

#### 2.3.4 QK Normalization

| 阶段         | 操作    | 计算负载 (FLOPs)                              | 内存访问 (Bytes)                                       |
| ------------ | ------- | --------------------------------------------- | ------------------------------------------------------ |
| Q Norm (txt) | RMSNorm | $B \times H \times L_{txt} \times d \times 4$ | $B \times H \times L_{txt} \times d \times 4 \times 2$ |
| K Norm (txt) | RMSNorm | $B \times H \times L_{txt} \times d \times 4$ | $B \times H \times L_{txt} \times d \times 4 \times 2$ |

### 2.4 联合注意力计算

#### 2.4.1 拼接 QKV

| 阶段     | 操作   | 计算负载 (FLOPs) | 内存访问 (Bytes)                        |
| -------- | ------ | ---------------- | --------------------------------------- |
| Concat Q | Memory | $0$              | $B \times H \times L \times d \times 4$ |
| Concat K | Memory | $0$              | $B \times H \times L \times d \times 4$ |
| Concat V | Memory | $0$              | $B \times H \times L \times d \times 4$ |

**说明**: L = L_txt + L_img

#### 2.4.2 RoPE 应用 (标准模式)

| 阶段           | 操作     | 计算负载 (FLOPs)                        | 内存访问 (Bytes)                                 |
| -------------- | -------- | --------------------------------------- | ------------------------------------------------ |
| Apply RoPE (Q) | Rotation | $B \times H \times L \times d \times 8$ | $B \times H \times L \times d \times 4 \times 3$ |
| Apply RoPE (K) | Rotation | $B \times H \times L \times d \times 8$ | $B \times H \times L \times d \times 4 \times 3$ |

**说明**: RoPE 应用涉及复数乘法和张量重塑

#### 2.4.3 RoPE 应用 (Liger 模式)

| 阶段             | 操作     | 计算负载 (FLOPs)                        | 内存访问 (Bytes)                                 |
| ---------------- | -------- | --------------------------------------- | ------------------------------------------------ |
| Liger RoPE (Q,K) | Rotation | $B \times H \times L \times d \times 6$ | $B \times H \times L \times d \times 4 \times 4$ |

#### 2.4.4 Flash Attention

**操作**: Scaled Dot-Product Attention (使用 Flash Attention 优化)

| 阶段          | 操作    | 计算负载 (FLOPs)                                 | 内存访问 (Bytes)          |
| ------------- | ------- | ------------------------------------------------ | ------------------------- |
| QK^T          | MatMul  | $2 \times B \times H \times L \times L \times d$ | IO 优化 (Flash Attention) |
| Softmax       | Softmax | $B \times H \times L \times L \times 5$          | IO 优化 (Flash Attention) |
| Attention × V | MatMul  | $2 \times B \times H \times L \times L \times d$ | IO 优化 (Flash Attention) |

**Flash Attention 内存访问优化**:

- 理论上: $O(B \times H \times L^2 \times d)$
- Flash Attention: $O(B \times H \times L \times d)$ (通过分块计算降低 HBM 访问)

#### 2.4.5 拆分注意力输出

| 阶段         | 操作   | 计算负载 (FLOPs) | 内存访问 (Bytes)               |
| ------------ | ------ | ---------------- | ------------------------------ |
| Split Output | Memory | $0$              | $B \times L \times D \times 4$ |

**说明**: 分离为 txt_attn (L_txt) 和 img_attn (L_img)

### 2.5 图像流 - 输出投影和 MLP

#### 2.5.1 注意力输出投影

| 阶段        | 操作         | 计算负载 (FLOPs)                              | 内存访问 (Bytes)                                             |
| ----------- | ------------ | --------------------------------------------- | ------------------------------------------------------------ |
| Proj (img)  | Linear(D, D) | $2 \times B \times L_{img} \times D \times D$ | $B \times L_{img} \times 2D \times 4 + (D \times D + D) \times 4$ |
| Gate × Proj | Elementwise  | $B \times L_{img} \times D$                   | $B \times L_{img} \times D \times 4 \times 2$                |
| 残差连接    | Add          | $B \times L_{img} \times D$                   | $B \times L_{img} \times D \times 4 \times 2$                |

#### 2.5.2 MLP 分支

| 阶段          | 操作             | 计算负载 (FLOPs)                                    | 内存访问 (Bytes)                                             |
| ------------- | ---------------- | --------------------------------------------------- | ------------------------------------------------------------ |
| LayerNorm     | Normalization    | $B \times L_{img} \times D \times 5$                | $B \times L_{img} \times D \times 4 \times 3$                |
| Scale + Shift | Elementwise      | $B \times L_{img} \times D \times 2$                | $B \times L_{img} \times D \times 4 \times 2$                |
| MLP Linear 1  | Linear(D, D_mlp) | $2 \times B \times L_{img} \times D \times D_{mlp}$ | $B \times L_{img} \times (D + D_{mlp}) \times 4 + (D \times D_{mlp} + D_{mlp}) \times 4$ |
| GELU          | Activation       | $B \times L_{img} \times D_{mlp} \times 8$          | $B \times L_{img} \times D_{mlp} \times 4 \times 2$          |
| MLP Linear 2  | Linear(D_mlp, D) | $2 \times B \times L_{img} \times D_{mlp} \times D$ | $B \times L_{img} \times (D_{mlp} + D) \times 4 + (D_{mlp} \times D + D) \times 4$ |
| Gate × MLP    | Elementwise      | $B \times L_{img} \times D$                         | $B \times L_{img} \times D \times 4 \times 2$                |
| 残差连接      | Add              | $B \times L_{img} \times D$                         | $B \times L_{img} \times D \times 4 \times 2$                |

**说明**: GELU 近似需要 8 次浮点运算 (包括多项式逼近)

### 2.6 文本流 - 输出投影和 MLP

#### 2.6.1 注意力输出投影

| 阶段        | 操作         | 计算负载 (FLOPs)                              | 内存访问 (Bytes)                                             |
| ----------- | ------------ | --------------------------------------------- | ------------------------------------------------------------ |
| Proj (txt)  | Linear(D, D) | $2 \times B \times L_{txt} \times D \times D$ | $B \times L_{txt} \times 2D \times 4 + (D \times D + D) \times 4$ |
| Gate × Proj | Elementwise  | $B \times L_{txt} \times D$                   | $B \times L_{txt} \times D \times 4 \times 2$                |
| 残差连接    | Add          | $B \times L_{txt} \times D$                   | $B \times L_{txt} \times D \times 4 \times 2$                |

#### 2.6.2 MLP 分支

| 阶段          | 操作             | 计算负载 (FLOPs)                                    | 内存访问 (Bytes)                                             |
| ------------- | ---------------- | --------------------------------------------------- | ------------------------------------------------------------ |
| LayerNorm     | Normalization    | $B \times L_{txt} \times D \times 5$                | $B \times L_{txt} \times D \times 4 \times 3$                |
| Scale + Shift | Elementwise      | $B \times L_{txt} \times D \times 2$                | $B \times L_{txt} \times D \times 4 \times 2$                |
| MLP Linear 1  | Linear(D, D_mlp) | $2 \times B \times L_{txt} \times D \times D_{mlp}$ | $B \times L_{txt} \times (D + D_{mlp}) \times 4 + (D \times D_{mlp} + D_{mlp}) \times 4$ |
| GELU          | Activation       | $B \times L_{txt} \times D_{mlp} \times 8$          | $B \times L_{txt} \times D_{mlp} \times 4 \times 2$          |
| MLP Linear 2  | Linear(D_mlp, D) | $2 \times B \times L_{txt} \times D_{mlp} \times D$ | $B \times L_{txt} \times (D_{mlp} + D) \times 4 + (D_{mlp} \times D + D) \times 4$ |
| Gate × MLP    | Elementwise      | $B \times L_{txt} \times D$                         | $B \times L_{txt} \times D \times 4 \times 2$                |
| 残差连接      | Add              | $B \times L_{txt} \times D$                         | $B \times L_{txt} \times D \times 4 \times 2$                |

### 2.7 Double Stream Block 总计 (单层)

| 阶段     | 计算负载 (FLOPs)                                             |
| -------- | ------------------------------------------------------------ |
| **总计** | $\approx 2 \times B \times (L_{img} + L_{txt}) \times D \times (12D + 8D_{mlp} + H \times L)$ |

**简化公式** (当 D_mlp = 4D, 忽略低阶项):
$$\text{FLOPs}_{\text{DoubleBlock}} \approx 2 \times B \times L \times D \times (44D + H \times L)$$

---

## 三、Single Stream Block (N_single 层)

Single Stream Block 处理拼接后的图像和文本序列。

### 3.1 Modulation

**操作**: SiLU → Linear(D, 3×D)

| 阶段      | 操作        | 计算负载 (FLOPs)                | 内存访问 (Bytes)                                           |
| --------- | ----------- | ------------------------------- | ---------------------------------------------------------- |
| SiLU 激活 | Elementwise | $B \times D \times 3$           | $B \times D \times 4 \times 2$                             |
| Linear    | Linear      | $2 \times B \times D \times 3D$ | $B \times (D + 3D) \times 4 + (D \times 3D + 3D) \times 4$ |

**说明**: 输出 3 个调制参数: shift, scale, gate

### 3.2 LayerNorm + Modulation

| 阶段          | 操作          | 计算负载 (FLOPs)               | 内存访问 (Bytes)                        |
| ------------- | ------------- | ------------------------------ | --------------------------------------- |
| LayerNorm     | Normalization | $B \times L \times D \times 5$ | $B \times L \times D \times 4 \times 3$ |
| Scale + Shift | Elementwise   | $B \times L \times D \times 2$ | $B \times L \times D \times 4 \times 2$ |

### 3.3 并行投影 (Fused 模式)

**操作**: Linear(D, 3×D + D_mlp)

| 阶段            | 操作   | 计算负载 (FLOPs)                                     | 内存访问 (Bytes)                                             |
| --------------- | ------ | ---------------------------------------------------- | ------------------------------------------------------------ |
| QKV + MLP 投影  | Linear | $2 \times B \times L \times D \times (3D + D_{mlp})$ | $B \times L \times (D + 3D + D_{mlp}) \times 4 + (D \times (3D + D_{mlp}) + (3D + D_{mlp})) \times 4$ |
| 分离 QKV 和 MLP | Memory | $0$                                                  | $B \times L \times (3D + D_{mlp}) \times 4$                  |
| Rearrange QKV   | Memory | $0$                                                  | $B \times L \times 3D \times 4$                              |

### 3.4 并行投影 (非 Fused 模式)

| 阶段         | 操作                 | 计算负载 (FLOPs)                                    | 内存访问 (Bytes)                                             |
| ------------ | -------------------- | --------------------------------------------------- | ------------------------------------------------------------ |
| Q 投影       | Linear(D, D)         | $2 \times B \times L \times D \times D$             | $B \times L \times 2D \times 4 + (D \times D + D) \times 4$  |
| K 投影       | Linear(D, D)         | $2 \times B \times L \times D \times D$             | $B \times L \times 2D \times 4 + (D \times D + D) \times 4$  |
| V + MLP 投影 | Linear(D, D + D_mlp) | $2 \times B \times L \times D \times (D + D_{mlp})$ | $B \times L \times (D + D + D_{mlp}) \times 4 + (D \times (D + D_{mlp}) + (D + D_{mlp})) \times 4$ |

### 3.5 QK Normalization

| 阶段   | 操作    | 计算负载 (FLOPs)                        | 内存访问 (Bytes)                                 |
| ------ | ------- | --------------------------------------- | ------------------------------------------------ |
| Q Norm | RMSNorm | $B \times H \times L \times d \times 4$ | $B \times H \times L \times d \times 4 \times 2$ |
| K Norm | RMSNorm | $B \times H \times L \times d \times 4$ | $B \times H \times L \times d \times 4 \times 2$ |

### 3.6 RoPE 应用

**同 Double Stream Block 2.4.2 或 2.4.3**

| 阶段               | 操作     | 计算负载 (FLOPs)                         | 内存访问 (Bytes)                                 |
| ------------------ | -------- | ---------------------------------------- | ------------------------------------------------ |
| Apply RoPE (标准)  | Rotation | $B \times H \times L \times d \times 16$ | $B \times H \times L \times d \times 4 \times 6$ |
| Apply RoPE (Liger) | Rotation | $B \times H \times L \times d \times 6$  | $B \times H \times L \times d \times 4 \times 4$ |

### 3.7 Flash Attention

| 阶段          | 操作    | 计算负载 (FLOPs)                                 | 内存访问 (Bytes)          |
| ------------- | ------- | ------------------------------------------------ | ------------------------- |
| QK^T          | MatMul  | $2 \times B \times H \times L \times L \times d$ | IO 优化 (Flash Attention) |
| Softmax       | Softmax | $B \times H \times L \times L \times 5$          | IO 优化 (Flash Attention) |
| Attention × V | MatMul  | $2 \times B \times H \times L \times L \times d$ | IO 优化 (Flash Attention) |

### 3.8 并行输出 MLP

#### 3.8.1 MLP 激活

| 阶段 | 操作       | 计算负载 (FLOPs)                     | 内存访问 (Bytes)                              |
| ---- | ---------- | ------------------------------------ | --------------------------------------------- |
| GELU | Activation | $B \times L \times D_{mlp} \times 8$ | $B \times L \times D_{mlp} \times 4 \times 2$ |

#### 3.8.2 拼接和投影

| 阶段     | 操作                 | 计算负载 (FLOPs)                                    | 内存访问 (Bytes)                                             |
| -------- | -------------------- | --------------------------------------------------- | ------------------------------------------------------------ |
| Concat   | Memory               | $0$                                                 | $B \times L \times (D + D_{mlp}) \times 4$                   |
| Linear 2 | Linear(D + D_mlp, D) | $2 \times B \times L \times (D + D_{mlp}) \times D$ | $B \times L \times (D + D_{mlp} + D) \times 4 + ((D + D_{mlp}) \times D + D) \times 4$ |

### 3.9 输出处理

| 阶段          | 操作        | 计算负载 (FLOPs)      | 内存访问 (Bytes)                        |
| ------------- | ----------- | --------------------- | --------------------------------------- |
| Gate × Output | Elementwise | $B \times L \times D$ | $B \times L \times D \times 4 \times 2$ |
| 残差连接      | Add         | $B \times L \times D$ | $B \times L \times D \times 4 \times 2$ |

### 3.10 Single Stream Block 总计 (单层)

| 阶段     | 计算负载 (FLOPs)                                             |
| -------- | ------------------------------------------------------------ |
| **总计** | $\approx 2 \times B \times L \times D \times (7D + 5D_{mlp} + H \times L)$ |

**简化公式** (当 D_mlp = 4D):
$$\text{FLOPs}_{\text{SingleBlock}} \approx 2 \times B \times L \times D \times (27D + H \times L)$$

---

## 四、输出层 (Final Layer)

### 4.1 AdaLN Modulation

**操作**: SiLU → Linear(D, 2×D)

| 阶段      | 操作        | 计算负载 (FLOPs)                | 内存访问 (Bytes)                                           |
| --------- | ----------- | ------------------------------- | ---------------------------------------------------------- |
| SiLU 激活 | Elementwise | $B \times D \times 3$           | $B \times D \times 4 \times 2$                             |
| Linear    | Linear      | $2 \times B \times D \times 2D$ | $B \times (D + 2D) \times 4 + (D \times 2D + 2D) \times 4$ |
| Chunk     | Memory      | $0$                             | $B \times 2D \times 4$                                     |

### 4.2 LayerNorm + Modulation

| 阶段          | 操作          | 计算负载 (FLOPs)                     | 内存访问 (Bytes)                              |
| ------------- | ------------- | ------------------------------------ | --------------------------------------------- |
| LayerNorm     | Normalization | $B \times L_{img} \times D \times 5$ | $B \times L_{img} \times D \times 4 \times 3$ |
| Scale + Shift | Elementwise   | $B \times L_{img} \times D \times 2$ | $B \times L_{img} \times D \times 4 \times 2$ |

**说明**: 仅处理图像序列部分 (L_img)

### 4.3 输出投影

**操作**: Linear(D, P² × C_out)

| 阶段   | 操作   | 计算负载 (FLOPs)                                             | 内存访问 (Bytes)                                             |
| ------ | ------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| Linear | Linear | $2 \times B \times L_{img} \times D \times (P^2 \times C_{out})$ | $B \times L_{img} \times (D + P^2 \times C_{out}) \times 4 + (D \times P^2 \times C_{out} + P^2 \times C_{out}) \times 4$ |

### 4.4 Final Layer 总计

| 阶段     | 计算负载 (FLOPs)                                             |
| -------- | ------------------------------------------------------------ |
| **总计** | $\approx 2 \times B \times L_{img} \times D \times (2D + P^2 \times C_{out})$ |

---

## 五、完整前向传播总计

### 5.1 总 FLOPs

$$
\begin{aligned}
\text{FLOPs}_{\text{total}} &= \text{FLOPs}_{\text{prepare}} \\
&+ N_{\text{double}} \times \text{FLOPs}_{\text{DoubleBlock}} \\
&+ N_{\text{single}} \times \text{FLOPs}_{\text{SingleBlock}} \\
&+ \text{FLOPs}_{\text{final}}
\end{aligned}
$$

**展开** (使用简化公式):

$$
\begin{aligned}
\text{FLOPs}_{\text{total}} &\approx 2 \times B \times D \times \Big[ \\
&\quad L_{img} \times C_{in} + L_{txt} \times D_{ctx} + (L_{img} + L_{txt}) \times 256 \\
&\quad + N_{\text{double}} \times (L_{img} + L_{txt}) \times (44D + H \times (L_{img} + L_{txt})) \\
&\quad + N_{\text{single}} \times (L_{img} + L_{txt}) \times (27D + H \times (L_{img} + L_{txt})) \\
&\quad + L_{img} \times (2D + P^2 \times C_{out}) \\
&\Big]
\end{aligned}
$$

### 5.2 主导项分析

**注意力计算主导**:
$$\text{FLOPs}_{\text{attention}} \approx 4 \times B \times H \times (N_{\text{double}} + N_{\text{single}}) \times L^2 \times d$$

**MLP 计算**:
$$\text{FLOPs}_{\text{MLP}} \approx 16 \times B \times (N_{\text{double}} + N_{\text{single}}) \times L \times D^2$$

**典型值** (D=3072, H=24, N_double=19, N_single=38):

- 对于短序列 (L < 1024): MLP 占主导
- 对于长序列 (L > 4096): Attention 占主导
- 临界点: $L \approx \sqrt{\frac{4D^2}{H \times d}} \approx 2048$

### 5.3 内存访问总计

**参数内存**:
$$
\begin{aligned}
\text{Params} &= 2 \times D \times (6D + 3D + C_{in} + D_{ctx} + P^2 \times C_{out}) \\
&+ (N_{\text{double}} + N_{\text{single}}) \times \Big[ \\
&\quad 2 \times D \times (9D + 8D_{mlp}) \\
&\Big]
\end{aligned}
$$

**激活内存** (峰值):
$$
\begin{aligned}
\text{Activations} &\approx B \times \Big[ \\
&\quad L \times D \times 4 \quad \text{(中间特征)} \\
&\quad + H \times L \times d \times 6 \quad \text{(QKV)} \\
&\quad + L \times D_{mlp} \quad \text{(MLP 中间)} \\
&\Big]
\end{aligned}
$$

---

## 六、分布式并行优化分析

### 6.1 Sequence Parallelism (Ring Attention)

**通信量** (每层):
$$\text{Comm}_{\text{ring}} = (P - 1) \times B \times \frac{L}{P} \times H \times d \times 4 \times 2$$

**说明**:

- P: 序列并行度
- 每个 rank 处理 L/P 长度
- 需要传输 KV 和 dKV (因子 2)

### 6.2 Tensor Parallelism

**通信量** (每层):
$$\text{Comm}_{\text{TP}} = 2 \times B \times L \times D \times 4 \times 4$$

**说明**:

- 4 次 All-Reduce (QKV proj, attn proj, MLP1, MLP2)
- 每次通信 BLD 张量

### 6.3 Pipeline Parallelism

**Bubble 比例**:
$$\text{Bubble} = \frac{(P - 1)}{M}$$

**说明**:

- P: Pipeline stage 数量
- M: Micro-batch 数量

---

## 七、优化技巧说明

### 7.1 Fused Kernels

1. **Fused QKV**: 减少 2 次 kernel launch 和内存访问
2. **Fused RMSNorm**: 单一 kernel 完成归一化和缩放
3. **Flash Attention**: 降低 HBM 访问从 $O(L^2)$ 到 $O(L)$

### 7.2 Gradient Checkpointing

**内存节约**:
$$\text{Memory}_{\text{saved}} \approx (1 - \frac{1}{\sqrt{N}}) \times \text{Activations}$$

**额外计算**:
$$\text{FLOPs}_{\text{recompute}} \approx \text{FLOPs}_{\text{forward}}$$

### 7.3 混合精度训练

**内存节约**:

- BF16/FP16: 50% 参数和激活内存
- FP32 主权重: 额外 100% 参数内存

**性能提升**:

- Tensor Core 加速: 2-4× (取决于硬件)

---

## 八、计算案例

### 案例参数设置

| 参数     | 值   |
| -------- | ---- |
| B        | 1    |
| L_img    | 4096 |
| L_txt    | 256  |
| D        | 3072 |
| H        | 24   |
| N_double | 19   |
| N_single | 38   |
| C_in     | 16   |
| C_out    | 16   |
| P        | 2    |

### 计算结果 (单位: TFLOPs)

| 阶段                 | FLOPs (TFLOPs) | 占比  |
| -------------------- | -------------- | ----- |
| 输入预处理           | $\approx 0.3$  | 0.1%  |
| Double Blocks (19层) | $\approx 180$  | 45%   |
| Single Blocks (38层) | $\approx 200$  | 50%   |
| Final Layer          | $\approx 0.2$  | 0.05% |
| **总计**             | $\approx 400$  | 100%  |

**说明**: 

- Attention: ~220 TFLOPs (55%)
- MLP: ~160 TFLOPs (40%)
- Others: ~20 TFLOPs (5%)

---

## 九、关键公式总结

### 9.1 矩阵乘法 FLOPs

$$\text{FLOPs}_{\text{matmul}}(M, N, K) = 2 \times M \times N \times K$$

### 9.2 Attention FLOPs

$$\text{FLOPs}_{\text{attn}} = 4 \times B \times H \times L^2 \times d$$

### 9.3 MLP FLOPs

$$\text{FLOPs}_{\text{MLP}} = 2 \times B \times L \times D \times (D_{in} + D_{out})$$

### 9.4 内存访问 (通用)

$$\text{Bytes} = \sum (\text{Inputs} + \text{Outputs} + \text{Weights}) \times \text{dtype\_size}$$

### 9.5 算术强度

$$\text{Arithmetic Intensity} = \frac{\text{FLOPs}}{\text{Bytes}}$$

---

## 十、参考文献和注释

### 10.1 理论基础

- **Flash Attention**: Dao et al., 2022
- **RoPE**: Su et al., 2021
- **MMDiT (Flux)**: Black Forest Labs, 2024

### 10.2 计算假设

1. 所有浮点数为 FP32 (4 bytes)
2. 不考虑 padding 开销
3. Flash Attention 内存访问按理论最优估计
4. 忽略小于 O(BLD) 的低阶项

### 10.3 符号约定

- $\times$: 标量乘法
- $\cdot$: 矩阵乘法
- $\approx$: 近似 (忽略低阶项)
- $O(\cdot)$: 渐近复杂度

---

## 附录: 典型配置表

| 配置  | D    | H    | N_double | N_single | 参数量 (B) | FLOPs/Token (GFLOPs) |
| ----- | ---- | ---- | -------- | -------- | ---------- | -------------------- |
| Small | 1536 | 12   | 12       | 24       | ~2         | ~50                  |
| Base  | 3072 | 24   | 19       | 38       | ~12        | ~200                 |
| Large | 4096 | 32   | 24       | 48       | ~20        | ~400                 |

**Token 定义**: 单个序列位置的单次前向传播

---

**文档版本**: v1.0  
**生成日期**: 2025年11月2日  
**适用模型**: MMDiT (Flux) - Open-Sora 实现