class_name MathX
extends RefCounted
## Probability helpers: logistic matchups, log-normal survival timing, softmax sampling, plus an inverse
## normal CDF and a gamma quantile.


static func sigmoid(x: float) -> float:
	if x >= 40.0:
		return 1.0
	if x <= -40.0:
		return 0.0
	return 1.0 / (1.0 + exp(-x))


static func logit(p: float, eps: float = 1e-6) -> float:
	var c := clampf(p, eps, 1.0 - eps)
	return log(c / (1.0 - c))


## z(r) = (r - 50) / 25 ; logit(p) = logit(p0) + clip(z_off - z_def + scheme + context, -clamp, clamp)
static func matchup_probability(p0: float, a_off: float, a_def: float, scheme_delta: float = 0.0,
		context_delta: float = 0.0, clamp_to: float = 3.0) -> float:
	var z_off := (a_off - 50.0) / 25.0
	var z_def := (a_def - 50.0) / 25.0
	var delta := clampf(z_off - z_def + scheme_delta + context_delta, -clamp_to, clamp_to)
	return sigmoid(logit(p0) + delta)


## Inverse standard normal CDF (Acklam's rational approximation, relative error ~1e-9).
static func norm_ppf(p: float) -> float:
	var a := [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
			1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00]
	var b := [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
			6.680131188771972e+01, -1.328068155288572e+01]
	var c := [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
			-2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00]
	var d := [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00, 3.754408661907416e+00]
	var pl := 0.02425
	if p <= 0.0:
		return -8.0
	if p >= 1.0:
		return 8.0
	if p < pl:
		var q := sqrt(-2.0 * log(p))
		return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / \
				((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0)
	if p > 1.0 - pl:
		var q2 := sqrt(-2.0 * log(1.0 - p))
		return -(((((c[0] * q2 + c[1]) * q2 + c[2]) * q2 + c[3]) * q2 + c[4]) * q2 + c[5]) / \
				((((d[0] * q2 + d[1]) * q2 + d[2]) * q2 + d[3]) * q2 + 1.0)
	var q3 := p - 0.5
	var r := q3 * q3
	return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q3 / \
			(((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1.0)


## Gamma(shape a, scale s) quantile via the Wilson-Hilferty approximation (accurate enough for a >= 2).
static func gamma_ppf(u: float, a: float, scale: float) -> float:
	var z := norm_ppf(clampf(u, 1e-6, 1.0 - 1e-6))
	var t := 1.0 / (9.0 * a)
	var x := 1.0 - t + z * sqrt(t)
	return maxf(0.0, a * scale * x * x * x)


## Log-normal survival model: calibrated so that P(T >= benchmark) = hold_probability.
static func sample_lognormal_time(hold_probability: float, rng: RandomNumberGenerator,
		benchmark: float = 2.5, sigma: float = 0.35) -> float:
	var p_hold := clampf(hold_probability, 0.001, 0.999)
	var mu := log(benchmark) - sigma * norm_ppf(1.0 - p_hold)
	var u := clampf(rng.randf(), 0.000001, 0.999999)
	return maxf(0.1, exp(mu + sigma * norm_ppf(u)))


## Softmax sample over `items` with `logits`.
static func softmax_sample(items: Array, logits: Array, rng: RandomNumberGenerator):
	if items.size() == 1:
		return items[0]
	var m: float = logits.max()
	var exps: Array = []
	var total := 0.0
	for l in logits:
		var e := exp(float(l) - m)
		exps.append(e)
		total += e
	var u := rng.randf()
	var cum := 0.0
	for i in items.size():
		cum += exps[i] / total
		if u <= cum:
			return items[i]
	return items[items.size() - 1]


static func normalize_joint(probs: Array) -> Array:
	var total := 0.0
	var out: Array = []
	for p in probs:
		var v := maxf(0.0, float(p))
		out.append(v)
		total += v
	if total <= 1e-9:
		var u := 1.0 / probs.size()
		return probs.map(func(_p): return u)
	return out.map(func(v): return v / total)


static func rint(x: float) -> int:
	return int(round(x))
