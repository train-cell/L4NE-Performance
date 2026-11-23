# Mathematical & Deterministic Analytics Specification (`l4ne-core` v1.2.0)

Every performance metric in **L4NE Training** is computed deterministically in `crates/l4ne-core/src/analytics.rs`, `crates/l4ne-core/src/engine.rs`, and `crates/l4ne-core/src/matcher.rs`.

---

## 1. Timed Distance Sports (Swimming, Finswimming, Track)

Let a logged session contain $N$ valid (`!is_skipped`, $t_i > 0$) repetitions with durations $t_1, t_2, \dots, t_N \in \mathbb{Z}^+$ (in milliseconds) and distances $d_1, d_2, \dots, d_N \in \mathbb{Z}^+$ (in meters).

### 1.1 Total Active Duration
$$T_{\text{total}} = \sum_{i=1}^{N} t_i \quad (\text{ms})$$

### 1.2 Homogeneous Mean, Best & Worst Repetition
Computed when `is_homogeneous == true` ($d_1 = d_2 = \dots = d_N$ and identical stroke/movement):
$$\bar{t} = \left\lfloor \frac{T_{\text{total}} + \lfloor N/2 \rfloor}{N} \right\rfloor, \quad t_{\text{best}} = \min_{1 \le i \le N} t_i, \quad t_{\text{worst}} = \max_{1 \le i \le N} t_i$$

### 1.3 Universal Weighted Pace per 100m ($P_{100}$)
Valid for **both** homogeneous sets and pyramids/compound sets of varying distances:
$$P_{100} = \left\lfloor \frac{\left(\sum_{i=1}^{N} t_i\right) \times 100 + \lfloor D_{\text{total}} / 2 \rfloor}{D_{\text{total}}} \right\rfloor \quad \text{where } D_{\text{total}} = \sum_{i=1}^{N} d_i$$

### 1.4 Dispersion ($\sigma$) & Consistency Coefficient of Variation ($\text{CV}\%$)
For $N \ge 2$, let $x_i = t_i$ for homogeneous sets, or $x_i = P_{100,i}$ (per-rep pace per 100m) for pyramids/compound sets:
$$\mu_x = \frac{1}{N} \sum_{i=1}^{N} x_i, \quad \sigma_x = \sqrt{\frac{1}{N} \sum_{i=1}^{N} (x_i - \mu_x)^2}, \quad \text{CV}(\%) = \text{round}_2\left(\frac{\sigma_x}{\mu_x} \times 100\right)$$

### 1.5 Fatigue / Pace Degradation Index ($\text{Fatigue}\%$)
For $N \ge 2$, let $h = \lfloor N / 2 \rfloor$. The set is partitioned into balanced first half $H_1 = \{1 \dots h\}$ and second half $H_2 = \{N - h + 1 \dots N\}$ (excluding the middle pivot when $N$ is odd):
$$\text{Fatigue}(\%) = \text{round}_2\left(\frac{P_{100}(H_2) - P_{100}(H_1)}{P_{100}(H_1)} \times 100\right)$$
- $\text{Fatigue} > 0\%$: Positive split (pace slowed down in the second half).
- $\text{Fatigue} < 0\%$: **Negative split** (athlete accelerated in the second half).

### 1.6 Send-Off Actual Rest ($R_i$) & Live Countdown
For a block with `RestMode::SendOff` and cycle interval $S$ (in ms):
$$R_i = \max(0, S - t_i)$$
During live poolside resting (`rest_elapsed_ms` $= e_{\text{rest}}$):
$$R_{\text{remaining}} = \max(0, R_i - e_{\text{rest}})$$

### 1.7 SWOLF Efficiency Score
When `stroke_count` $c_i > 0$ is recorded on repetition $i$:
$$\text{SWOLF}_i = \left\lfloor \frac{t_i + 500}{1000} \right\rfloor + c_i$$

---

## 2. Strength / Gym Analytics (`RecordKind::WeightReps`)

Given active sets with load $w_i > 0$ (in kg) and completed repetitions $r_i > 0$:

- **Total Session Tonnage (kg):**
  $$\text{Tonnage} = \text{round}_2\left(\sum_{i=1}^{N} w_i \cdot r_i\right)$$
- **Epley Estimated 1-Rep Max ($\text{1RM}$ in kg):**
  $$\text{1RM}_i = \begin{cases} w_i & \text{if } r_i = 1 \\ \text{round}_2\left(w_i \times \left(1 + \frac{r_i}{30}\right)\right) & \text{if } r_i > 1 \end{cases}$$

---

## 3. Field Throws & Jumps (`RecordKind::DistanceAttempt`)

Given valid attempts $a_i > 0$ (in meters):
$$A_{\text{best}} = \max_{1 \le i \le N} \text{round}_2(a_i)$$

---

## 4. Historical Session Comparison ($\text{Improvement}\%$)

- **For Timed Protocols (lower time = better performance):**
  $$\text{Improvement}(\%) = \text{round}_2\left(\frac{T_{\text{baseline}} - T_{\text{current}}}{T_{\text{baseline}}} \times 100\right)$$
- **For Gym Tonnage / Field Attempts (higher value = better performance):**
  $$\text{Improvement}(\%) = \text{round}_2\left(\frac{V_{\text{current}} - V_{\text{baseline}}}{V_{\text{baseline}}} \times 100\right)$$
