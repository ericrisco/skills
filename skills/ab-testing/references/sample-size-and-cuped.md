# Sample size, duration, CUPED, and SRM — runnable snippets

Versions assumed: **statsmodels 0.14.6** (stable), **scipy 1.17.1**. Install: `pip install "statsmodels>=0.14" "scipy>=1.15"`.

All snippets are self-contained and print the numbers they compute.

## 1. Sample size for a conversion rate (proportion)

`proportion_effectsize` applies the arcsine (Cohen's h) transform so the normal-approximation power
calculation is valid for proportions.

```python
import math
from statsmodels.stats.power import NormalIndPower
from statsmodels.stats.proportion import proportion_effectsize

baseline = 0.12          # control conversion
mde_abs  = 0.015         # minimum detectable effect, absolute (1.5 percentage points)
alpha    = 0.05          # two-sided
power    = 0.80

variant = baseline + mde_abs
h = proportion_effectsize(baseline, variant)
n_per_arm = NormalIndPower().solve_power(effect_size=h, alpha=alpha, power=power, ratio=1.0)
n_per_arm = math.ceil(n_per_arm)
print(f"n per arm = {n_per_arm}, total = {2 * n_per_arm}")
```

Worked numbers for the example above: h ≈ 0.0449, **n per arm ≈ 7,773**, total ≈ 15,546.

## 2. Sample size for a continuous metric

Effect size is Cohen's d = (mean difference you care about) / (pooled standard deviation). Estimate the
std from historical data on the same metric.

```python
import math
from statsmodels.stats.power import TTestIndPower

mde_units  = 0.50        # e.g. detect a $0.50 lift in revenue per user
pooled_std = 4.0         # historical std of revenue per user
d = mde_units / pooled_std
n_per_arm = math.ceil(TTestIndPower().solve_power(effect_size=d, alpha=0.05, power=0.80, ratio=1.0))
print(f"n per arm = {n_per_arm}")
```

## 3. n → calendar duration

```python
import math

n_per_arm = 7773
num_arms  = 2
daily_eligible = 1800            # users entering the experiment per day

days = math.ceil((n_per_arm * num_arms) / daily_eligible)
print(f"raw days = {days}; run full weeks ->", math.ceil(days / 7) * 7)
```

Round **up to whole weeks**. A test that mathematically needs 9 days should run 14: weekday and weekend
users are different populations, and stopping mid-week oversamples one slice.

## 4. Analyze a finished proportion test

```python
import numpy as np
from statsmodels.stats.proportion import proportions_ztest, proportion_confint

conv  = np.array([540, 590])     # successes: control, variant
nobs  = np.array([10000, 10000]) # exposures per arm

stat, pval = proportions_ztest(conv, nobs)
p_c, p_v = conv / nobs
lift_abs = p_v - p_c
lift_rel = lift_abs / p_c
# CI on the difference of two proportions (Wald)
se = ((p_c*(1-p_c)/nobs[0]) + (p_v*(1-p_v)/nobs[1])) ** 0.5
lo, hi = lift_abs - 1.96*se, lift_abs + 1.96*se
print(f"control={p_c:.3%} variant={p_v:.3%} abs lift={lift_abs:+.3%} ({lift_rel:+.1%} rel)")
print(f"p={pval:.4f}  95% CI on abs lift=[{lo:+.3%}, {hi:+.3%}]")
```

Read it as a triple: lift, CI, p. Compare the CI to your MDE — if the interval includes effects below
the MDE, you have not shown a *practically* meaningful result even if p < 0.05.

## 5. CUPED — θ via OLS, then test the adjusted metric

```python
import numpy as np
import statsmodels.api as sm
from scipy import stats

# y  = in-experiment metric per user (e.g. spend during the test)
# x  = SAME metric measured in the pre-experiment window (must be pre-assignment)
# arm = 0 control, 1 variant

X = sm.add_constant(x)
theta = sm.OLS(y, X).fit().params[1]          # slope = Cov(y,x)/Var(x)
y_cuped = y - theta * (x - x.mean())          # variance-reduced metric

t, p = stats.ttest_ind(y_cuped[arm == 1], y_cuped[arm == 0], equal_var=False)
var_reduction = 1 - y_cuped.var() / y.var()
print(f"theta={theta:.3f}  variance reduction={var_reduction:.1%}  t={t:.2f} p={p:.4f}")
```

`var_reduction` is the fraction of variance the covariate explained — that is the power you bought for
free. Zero or negative means the covariate is useless here (new users, or `x` uncorrelated with `y`):
drop CUPED, it cannot help and a post-assignment covariate would actively bias the estimate.

## 6. Sample ratio mismatch (SRM) gate

Run this *before* trusting any result. A significant deviation from the intended split means the
experiment is broken at the assignment/logging layer.

```python
from scipy import stats

observed = [10000, 9430]          # users actually seen in each arm
expected_ratio = [0.5, 0.5]       # intended split
total = sum(observed)
expected = [total * r for r in expected_ratio]

chi2, p = stats.chisquare(f_obs=observed, f_exp=expected)
print(f"chi2={chi2:.1f} p={p:.6f}", "-> SRM, do not trust results" if p < 0.001 else "-> split OK")
```

If `p < 0.001`: stop, find why one arm is short (bot filtering, redirect, caching, a broken bucketing
hash), fix instrumentation, and rerun. Never reweight your way out of an SRM.
