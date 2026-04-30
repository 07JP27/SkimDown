# 数式（Math / KaTeX）

SkimDown は KaTeX を使って美しい数式を描画します。

## インライン数式

アインシュタインの有名な方程式 $E = mc^2$ はエネルギーと質量の等価性を表します。

二次方程式 $ax^2 + bx + c = 0$ の解は $x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$ で求められます。

円の面積は $A = \pi r^2$、円周は $C = 2\pi r$ です。

## ディスプレイ数式

### 二次方程式の解の公式

$$
x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}
$$

### オイラーの等式

$$
e^{i\pi} + 1 = 0
$$

### ガウス積分

$$
\int_{-\infty}^{\infty} e^{-x^2} \, dx = \sqrt{\pi}
$$

### テイラー展開

$$
f(x) = \sum_{n=0}^{\infty} \frac{f^{(n)}(a)}{n!}(x - a)^n
$$

### 行列

$$
A = \begin{pmatrix}
a_{11} & a_{12} & a_{13} \\
a_{21} & a_{22} & a_{23} \\
a_{31} & a_{32} & a_{33}
\end{pmatrix}
$$

### 連立方程式

$$
\begin{cases}
3x + 2y = 7 \\
x - y = 1
\end{cases}
$$

### ナビエ・ストークス方程式

$$
\rho \left( \frac{\partial \mathbf{v}}{\partial t} + \mathbf{v} \cdot \nabla \mathbf{v} \right) = -\nabla p + \mu \nabla^2 \mathbf{v} + \mathbf{f}
$$

### シュレーディンガー方程式

$$
i\hbar \frac{\partial}{\partial t} \Psi(\mathbf{r}, t) = \hat{H} \Psi(\mathbf{r}, t)
$$

## ギリシャ文字と記号

- アルファ: $\alpha$, ベータ: $\beta$, ガンマ: $\gamma$, デルタ: $\delta$
- シグマ: $\sigma$, パイ: $\pi$, オメガ: $\omega$, ラムダ: $\lambda$
- 無限大: $\infty$, 偏微分: $\partial$, ナブラ: $\nabla$
- 集合: $\mathbb{R}$, $\mathbb{Z}$, $\mathbb{N}$, $\mathbb{C}$
- 論理: $\forall$, $\exists$, $\Rightarrow$, $\Leftrightarrow$
