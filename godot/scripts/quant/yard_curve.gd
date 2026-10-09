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
		y = exp(log(float(th.med)) + float(th.sig) * MathX.norm_ppf(clampf(rng.randf(), 1e-6, 1.0 - 1e-6)))
	return {"yards": int(round(y)), "turnover": turnover}
