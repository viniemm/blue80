class_name YardCurve
extends RefCounted
## A play's yardage distribution from ~8 constants (theta), all closed form.
##
## Outcomes of one snap:
##   p_neg   loss / sack            Y = -(1 + Exp(mean = loss))
##   p_to    turnover               same yardage as a loss, plus a turnover flag
##   p_zero  no gain / incomplete   Y = 0
##   p_big   explosive play         Y = XB + Exp(mean = tail)
##   rest    normal gain            Y ~ LogNormal(median = med, sigma = sig)
## Yards are integers (the continuous draw is rounded), so P(Y >= t) = S(t - 0.5).

const XB := 15.0   # explosive plays start here


static func erf(x: float) -> float:
	var sign_v := 1.0 if x >= 0.0 else -1.0
	var a := absf(x)
	var t := 1.0 / (1.0 + 0.3275911 * a)
	var y := 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-a * a)
	return sign_v * y


static func phi(x: float) -> float:
	return 0.5 * (1.0 + erf(x / sqrt(2.0)))


static func p_normal(th: Dictionary) -> float:
	var v: float = 1.0 - float(th.p_neg) - float(th.p_to) - float(th.p_zero) - float(th.p_big)
	return maxf(0.02, v)


## P(yards >= t) for integer t. Negative t means "loses no more than |t| yards".
static func survival(th: Dictionary, t: int) -> float:
	if t <= 0:
		var pl: float = float(th.p_neg) + float(th.p_to)
		if t == 0:
			return 1.0 - pl
		var u := -float(t) - 0.5
		return (1.0 - pl) + pl * (1.0 - exp(-u / float(th.loss)))
	var x := float(t) - 0.5
	var g: float = 1.0 - phi((log(x) - log(float(th.med))) / float(th.sig))
	var tail := 1.0 if x <= XB else exp(-(x - XB) / float(th.tail))
	return p_normal(th) * g + float(th.p_big) * tail


## Expected yards (continuous approximation; rounding shifts it by a hair).
static func mean(th: Dictionary) -> float:
	var losses: float = (float(th.p_neg) + float(th.p_to)) * (1.0 + float(th.loss))
	var normal: float = p_normal(th) * float(th.med) * exp(0.5 * float(th.sig) * float(th.sig))
	var big: float = float(th.p_big) * (XB + float(th.tail))
	return normal + big - losses


## Standard deviation, from the exact mixture second moment.
static func stdev(th: Dictionary) -> float:
	var pl: float = float(th.p_neg) + float(th.p_to)
	var ml: float = 1.0 + float(th.loss)
	var e2_loss: float = ml * ml + float(th.loss) * float(th.loss)          # E[(1+Exp)^2] = (1+m)^2 + m^2
	var med: float = float(th.med)
	var sig: float = float(th.sig)
	var e2_norm: float = med * med * exp(2.0 * sig * sig)
	var e2_big: float = (XB + float(th.tail)) * (XB + float(th.tail)) + float(th.tail) * float(th.tail)
	var e2: float = pl * e2_loss + p_normal(th) * e2_norm + float(th.p_big) * e2_big
	var m := mean(th)
	return sqrt(maxf(0.0, e2 - m * m))


## P(loss size >= t) for a lost snap: the loss is 1 + Exp(mean = th.loss), rounded.
static func loss_survival(th: Dictionary, t: int) -> float:
	if t <= 1:
		return 1.0
	return exp(-(float(t) - 1.5) / float(th.loss))


## How many yards a losing snap costs (always at least 1), for the loss wheel.
static func sample_loss(th: Dictionary, rng: RandomNumberGenerator) -> int:
	return maxi(1, int(round(1.0 + (-log(1.0 - rng.randf()) * float(th.loss)))))


## A gain for the outcome wheel: the curve conditioned on gaining at least a yard, so the wheel holds positive yardage only.
static func sample_gain(th: Dictionary, rng: RandomNumberGenerator) -> int:
	for i in 60:
		var s := sample(th, rng)
		if s.yards >= 1 and not s.turnover:
			return int(s.yards)
	return 1


## Draws one snap: {yards:int, turnover:bool}.
static func sample(th: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var u := rng.randf()
	var p_neg: float = th.p_neg
	var p_to: float = th.p_to
	var p_zero: float = th.p_zero
	var p_big: float = th.p_big
	var y := 0.0
	var turnover := false
	if u < p_neg + p_to:
		y = -(1.0 + (-log(1.0 - rng.randf()) * float(th.loss)))
		turnover = u >= p_neg
	elif u < p_neg + p_to + p_zero:
		y = 0.0
	elif u < p_neg + p_to + p_zero + p_big:
		y = XB + (-log(1.0 - rng.randf()) * float(th.tail))
	else:
		y = exp(log(float(th.med)) + float(th.sig) * _norm_ppf(clampf(rng.randf(), 1e-6, 1.0 - 1e-6)))
	return {"yards": int(round(y)), "turnover": turnover}


## Inverse standard normal CDF (Acklam's rational approximation, relative error ~1e-9).
static func _norm_ppf(p: float) -> float:
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
