# Reader-facing examples for the exdqlm JSS article.
#
# This script collects the main code patterns shown in the manuscript in a
# compact, copy/paste-friendly form. It is intended for readers who want to
# adapt the examples. For exact replication of all figures, tables, and
# manuscript outputs, use the standalone driver:
#
#   Rscript code.R
#
# The full replication driver uses the scripts in analysis/manuscript/ and
# records provenance for the generated outputs.

library("exdqlm")


#####################
#### example 5.1 ####
#####################

model = polytrendMod(order = 2, m0 = c(579, 0),
                        C0 = 10 * diag(2))
model

set.seed(20260501)
M95 = exdqlmMCMC(y = LakeHuron, p0 = 0.95, model = model,
                    df = 0.9, dim.df = 2,
                    PriorGamma = list(m_gam = -1, s_gam = 0.1, df_gam = 1),
                    n.burn = 2000, n.mcmc = 3000, verbose = FALSE)
M50 = exdqlmMCMC(y = LakeHuron, p0 = 0.50, model = model,
                    df = 0.9, dim.df = 2,
                    PriorGamma = list(m_gam = 0, s_gam = 0.1, df_gam = 1),
                    n.burn = 2000, n.mcmc = 3000, verbose = FALSE)
M5 = exdqlmMCMC(y = LakeHuron, p0 = 0.05, model = model,
                   df = 0.9, dim.df = 2,
                   PriorGamma = list(m_gam = 1, s_gam = 0.1, df_gam = 1),
                   n.burn = 2000, n.mcmc = 3000, verbose = TRUE, verbose.every = 1000)

set.seed(20260620)
M50.trace = exdqlmMCMC(y = LakeHuron, p0 = 0.50, model = model,
                          df = 0.9, dim.df = 2,
                          PriorGamma = list(m_gam = 0, s_gam = 0.1,
                                              df_gam = 1),
                          n.burn = 7000, n.mcmc = 3000,
                          verbose = FALSE)
par(mfcol = c(2, 2), mar = c(4.1, 4.1, 2.1, 1.0))
keep.idx = seq(1, length(M50.trace$samp.sigma), by = 10)
sigma.trace = coda::mcmc(M50.trace$samp.sigma[keep.idx], thin = 10)
gamma.trace = coda::mcmc(M50.trace$samp.gamma[keep.idx], thin = 10)
coda::traceplot(sigma.trace, main = "sigma trace")
coda::densplot(sigma.trace, main = "sigma density")
coda::traceplot(gamma.trace, main = "gamma trace")
coda::densplot(gamma.trace, main = "gamma density")

M50 = exdqlmMCMC(y = LakeHuron, p0 = 0.50, model = model,
                    df = 0.9, dim.df = 2,
                    gam.init = 0, fix.gamma = TRUE,
                    n.burn = 2000, n.mcmc = 3000, verbose = FALSE)

par(mfrow = c(2, 2), mar = c(4.4, 4.1, 2.2, 1.2),
       oma = c(0, 0, 0.8, 0))
plot(M95); title("(a) Dynamic quantiles")
plot(M50, add = TRUE, col = "blue")
plot(M5, add = TRUE, col = "forest green")
legend("topright", lty = 1, bty = "n",
          col = c("purple", "blue", "forest green"),
          legend = c(expression('p'[0]*'=0.95'), expression('p'[0]*'=0.50'),
                       expression('p'[0]*'=0.05')))

fFF = model$FF
fGG = model$GG

plot(LakeHuron, xlim = c(1952, 1980), ylim = c(575, 582),
        col = "dark grey", main = "(b) Forecasted quantiles",
        ylab = "forecast 95% CrIs")
fc95 = predict(M95, start.t = length(LakeHuron), k = 8,
                  fFF = fFF, fGG = fGG, return.draws = TRUE)
fc50 = predict(M50, start.t = length(LakeHuron), k = 8,
                  fFF = fFF, fGG = fGG, return.draws = TRUE)
fc05 = predict(M5, start.t = length(LakeHuron), k = 8,
                  fFF = fFF, fGG = fGG, return.draws = TRUE)
plot(fc95, add = TRUE)
plot(fc50, add = TRUE, cols = c("blue", "light blue"))
plot(fc05, add = TRUE, cols = c("forest green", "green"))

syn.obs = quantileSynthesis(
  draws_list = list(M5, M50, M95),
  p = c(0.05, 0.50, 0.95),
  T_expected = length(LakeHuron))

syn.fore = quantileSynthesis(
  draws_list = list(fc05, fc50, fc95),
  p = c(0.05, 0.50, 0.95),
  T_expected = 8)

synth.obs.col = adjustcolor("#F7D6DE", alpha.f = 0.40)
synth.fore.col = adjustcolor("#D98A9B", alpha.f = 0.38)
plot(syn.obs, y = LakeHuron, time = as.numeric(time(LakeHuron)),
        xlim = c(1880, 1972), ylim = c(575.75,582.25),
        ylab = "predictive synthesis",
        main = "(c) Observed-period synthesis",
        show.median = FALSE, band.col = synth.obs.col,
        y.col = adjustcolor("grey30", alpha.f = 0.62))
legend("bottomleft",
          legend = "Synthesized posterior predictive interval (95%)",
          fill = synth.obs.col, border = NA, bty = "n", cex = 0.68)
plot(syn.obs, y = LakeHuron, time = as.numeric(time(LakeHuron)),
        xlim = c(1952, 1980), ylim = c(575.75,581),
        ylab = "predictive synthesis",
        main = "(d) Forecast synthesis",
        show.median = FALSE, band.col = synth.obs.col,
        y.col = adjustcolor("grey30", alpha.f = 0.62))
polygon(c(1972, 1973, 1973, 1972),
           c(tail(syn.obs$summary$q025, 1), syn.fore$summary$q025[1],
               syn.fore$summary$q975[1], tail(syn.obs$summary$q975, 1)),
           col = synth.fore.col, border = NA)
plot(syn.fore, time = 1973:1980, add = TRUE,
        show.median = FALSE, band.col = synth.fore.col)
abline(v = 1972, lty = 3)
legend("bottomleft",
          legend = c("Observed-period synthesis (95%)",
                       "Forecast synthesis (95%)"),
          fill = c(synth.obs.col, synth.fore.col), border = NA,
          bty = "n", cex = 0.66)


#####################
#### example 5.2 ####
#####################

dlm.trend.comp = dlm::dlmModPoly(1, m0 = 50, C0 = 2500)
trend.comp = as.exdqlm(dlm.trend.comp)

seas.comp = seasMod(p = 11, h = 1:4, C0 = 10 * diag(8))

model = trend.comp + seas.comp

model$GG

M1 = exdqlmLDVB(y = sunspot.year, p0 = 0.85, model = model,
                   df = c(0.9, 0.85), dim.df = c(1, 8),
                   dqlm.ind = TRUE, fix.sigma = FALSE,
                   n.samp = 3000, verbose = FALSE)
M2 = exdqlmLDVB(y = sunspot.year, p0 = 0.85, model = model,
                   df = c(0.9, 0.85), dim.df = c(1, 8),
                   fix.sigma = FALSE,
                   n.samp = 3000, verbose = FALSE)

plot(sunspot.year, xlim = c(1780, 1830), col = "dark grey",
        ylab = "quantile 95% CrIs")
plot(M1, add = TRUE, col = "red")
plot(M2, add = TRUE, col = "blue")
legend("topleft", lty = 1, bty = "n", col = c("red", "blue"),
          legend = c("DQLM", "exDQLM"))
title("LDVB fit for p0 = 0.85")

hist(M2$samp.gamma, xlab = expression(gamma), main = "",
        col = adjustcolor("#4C72B0", alpha.f = 0.22),
        border = "#4C72B0")
abline(v = median(M2$samp.gamma), col = "#4C72B0", lwd = 2)
title("exDQLM posterior draws of gamma (p0 = 0.85)")

par(mfrow = c(2, 3))
diagM1M2 = diagnostics(M1, M2)
plot(diagM1M2, cols = c("red", "blue"))

print(diagM1M2)

possible.dfs = cbind(0.9, seq(0.85, 1, 0.05))
possible.dfs

metrics <- matrix(NA_real_, nrow(possible.dfs), 2,
                     dimnames = list(NULL, c("CRPS", "KL")))
for (i in 1:nrow(possible.dfs)) {
  temp.M2 = exdqlmLDVB(y = sunspot.year, p0 = 0.85, model = model,
                         df = possible.dfs[i, ], dim.df = c(1, 8),
                         sig.init = 2, fix.sigma = FALSE,
                         n.samp = 3000, verbose = FALSE)
  temp.check = diagnostics(temp.M2)
  metrics[i, ] = c(temp.check$m1.CRPS, temp.check$m1.KL)
  }
possible.dfs[which.min(metrics[, "CRPS"]), ]

M1mcmc = exdqlmMCMC(y = sunspot.year, p0 = 0.85, model = model,
                       df = c(0.9, 0.85), dim.df = c(1, 8),
                       n.burn = 2000, n.mcmc = 3000, verbose = FALSE,
                       dqlm.ind = TRUE, fix.sigma = FALSE)
M2mcmc = exdqlmMCMC(y = sunspot.year, p0 = 0.85, model = model,
                       df = c(0.9, 0.85), dim.df = c(1, 8),
                       n.burn = 2000, n.mcmc = 3000, verbose = FALSE,
                       fix.sigma = FALSE)


#####################
#### example 5.3 ####
#####################

data("BTflow", package = "exdqlm")
data("climateIndices", package = "exdqlm")
ex3.dates = seq(as.Date("1987-01-01"), by = "month",
                   length.out = length(BTflow))
flow.df = data.frame(date = ex3.dates, flow = as.numeric(BTflow))
ex3.df = merge(flow.df, climateIndices[, c("date", "noi", "amo")],
                  by = "date")
ex3.df = ex3.df[1:432, ]
y.fit = ts(log(ex3.df$flow), start = c(1987, 1), frequency = 12)
y.train = window(y.fit, end = c(2021, 6))
y.holdout = window(y.fit, start = c(2021, 7))
X.raw = as.matrix(ex3.df[, c("noi", "amo")])
X.train = scale(X.raw[1:414, ])
X.holdout = scale(X.raw[415:432, ],
                     center = attr(X.train, "scaled:center"),
                     scale = attr(X.train, "scaled:scale"))

trend.comp = polytrendMod(1, m0 = log(50), C0 = 1)
seas.comp = seasMod(p = 12, h = c(1, 2, 0.1469118636),
                       C0 = diag(1, 6))
model = trend.comp + seas.comp

lambda.grid = c(0.70, 0.75, 0.80, 0.85, 0.90, 0.95, 0.99)
pplc.grid = rep(NA_real_, length(lambda.grid))
for (i in seq_along(lambda.grid)) {
  set.seed(20264001 + i)
  temp.MTF = exdqlmTransferLDVB(y = y.train, p0 = 0.15, model = model,
                                  df = c(0.99, 0.99), dim.df = c(1, 6),
                                  X = X.train, tf.df = c(0.99, 1),
                                  lam = lambda.grid[i], tf.m0 = rep(0, 3),
                                  tf.C0 = diag(c(0.1, 1, 1), 3),
                                  sig.init = 0.1, gam.init = -0.1,
                                  n.samp = 1000, tol = 0.05, verbose = FALSE)
  temp.diag = diagnostics(temp.MTF)
  pplc.grid[i] = temp.diag$m1.pplc
  }
lambda.star = lambda.grid[which.min(pplc.grid)]
lambda.star

set.seed(20264101)
M0 = exdqlmLDVB(y = y.train, p0 = 0.15, model = model,
                   df = c(0.99, 0.99), dim.df = c(1, 6),
                   sig.init = 0.1, gam.init = -0.1,
                   n.samp = 1000, tol = 0.05, verbose = FALSE)
reg.comp = regMod(X.train, m0 = rep(0, 2), C0 = diag(1, 2))
set.seed(20264301)
MREG = exdqlmLDVB(y = y.train, p0 = 0.15,
                     model = model + reg.comp,
                     df = c(0.99, 0.99, 1), dim.df = c(1, 6, 2),
                     sig.init = 0.1, gam.init = -0.1,
                     n.samp = 1000, tol = 0.05, verbose = FALSE)
set.seed(20264201)
MTF = exdqlmTransferLDVB(y = y.train, p0 = 0.15, model = model,
                            df = c(0.99, 0.99), dim.df = c(1, 6),
                            X = X.train, tf.df = c(0.99, 1),
                            lam = lambda.star, tf.m0 = rep(0, 3),
                            tf.C0 = diag(c(0.1, 1, 1), 3),
                            sig.init = 0.1, gam.init = -0.1,
                            n.samp = 1000, tol = 0.05, verbose = FALSE)

par(mfrow = c(3, 1), mar = c(2.8, 4.4, 1.0, 0.9),
       oma = c(1.8, 0, 0, 0))
plot(y.train, col = "grey", ylim = c(1, 8), xlim = c(2016, 2020),
        ylab = "log flow / quantile")
grid(col = "grey90")
plot(M0, add = TRUE)
plot(MREG, add = TRUE, col = "steelblue")
plot(MTF, add = TRUE, col = "forest green")
legend("topleft",
          legend = c("M0 no covariates", "MREG direct regression",
                       "MTF transfer function"),
          col = c("purple", "steelblue", "forest green"),
          lty = 1, lwd = 1.5, bty = "n")

plot(NA, ylim = c(-2, 2), xlim = c(2016, 2020),
        ylab = "seasonal components")
grid(col = "grey90")
plot(M0, type = "component", index = 2:7, add = TRUE)
plot(MREG, type = "component", index = 2:7,
        add = TRUE, col = "steelblue")
plot(MTF, type = "component", index = 2:7,
        add = TRUE, col = "forest green")
abline(h = 0, col = "orange", lty = 3, lwd = 1.4)

plot(NA, ylim = c(-1.5, 1.5), xlim = c(2016, 2020),
        ylab = "covariate contribution")
grid(col = "grey90")
plot(MREG, type = "component", index = 8:9,
        add = TRUE, col = "steelblue")
plot(MTF, type = "component", index = 8,
        add = TRUE, col = "forest green")
abline(h = 0, col = "orange", lty = 3, lwd = 1.4)
legend("topleft", legend = c("MREG direct", "MTF transfer"),
          col = c("steelblue", "forest green"), lty = 1, lwd = 1.5,
          bty = "n")

layout(matrix(c(1, 1, 2, 3), nrow = 2, byrow = TRUE))
plot(MTF, type = "state", index = 8, col = "forest green",
        add = FALSE)
grid(col = "grey90")
abline(h = 0, col = "orange", lty = 3, lwd = 1.4)
title(expression(zeta[t]))
par(mar = c(3.8, 4.2, 2.1, 0.8))
plot(y.train, type = "n", ylim = c(-0.11, 0.01),
        xlab = "time", ylab = "component CrIs")
plot(MTF, type = "state", index = 9, col = "steelblue",
        add = TRUE)
abline(h = 0, col = "orange", lty = 3, lwd = 1.4)
title(expression(psi[list(NOI, t)]))
plot(y.train, type = "n", ylim = c(-0.005, 0.06),
        xlab = "time", ylab = "component CrIs")
plot(MTF, type = "state", index = 10, col = "darkorange",
        add = TRUE)
abline(h = 0, col = "orange", lty = 3, lwd = 2)
title(expression(psi[list(AMO, t)]))

MTF$median.kt

k.fore = length(y.holdout)
F0.future = model$FF
G0.future = model$GG
fc.M0 = predict(M0, start.t = length(y.train), k = k.fore,
                   fFF = F0.future, fGG = G0.future,
                   return.draws = TRUE, n.samp = 1000,
                   seed = 20265101)

n.x = ncol(X.holdout)
reg.future = regMod(X.holdout, m0 = rep(0, n.x), C0 = diag(1, n.x))
model.reg.future = model + reg.future
FREG.future = model.reg.future$FF
GREG.future = model.reg.future$GG
fc.MREG = predict(MREG, start.t = length(y.train), k = k.fore,
                     fFF = FREG.future, fGG = GREG.future,
                     return.draws = TRUE, n.samp = 1000,
                     seed = 20265301)

n.state = length(model$m0)
FTF.future = matrix(0, nrow = n.state + n.x + 1, ncol = k.fore)
FTF.future[seq_len(n.state), ] = F0.future
FTF.future[n.state + 1, ] = 1
GTF.future = array(0, c(n.state + n.x + 1,
                           n.state + n.x + 1, k.fore))
GTF.future[seq_len(n.state), seq_len(n.state), ] = G0.future
zeta.ind = n.state + 1
psi.ind = n.state + 1 + seq_len(n.x)
GTF.future[zeta.ind, zeta.ind, ] = lambda.star
for (j in seq_len(n.x)) {
  GTF.future[zeta.ind, psi.ind[j], ] = X.holdout[, j]
  GTF.future[psi.ind[j], psi.ind[j], ] = 1
  }
fc.MTF = predict(MTF, start.t = length(y.train), k = k.fore,
                    fFF = FTF.future, fGG = GTF.future,
                    return.draws = TRUE, n.samp = 1000,
                    seed = 20265201)

plot(y.fit, col = "grey70", xlim = c(2020, 2023), ylim = c(1,8),
        ylab = "log flow / forecast quantile", xlab = "time")
grid(col = "grey90")
plot(fc.M0, add = TRUE, cols = c("purple", "plum"))
plot(fc.MREG, add = TRUE, cols = c("steelblue", "lightblue"))
plot(fc.MTF, add = TRUE, cols = c("forest green", "darkseagreen"))
t.all = as.numeric(time(y.fit))
hold.idx = 415:432
lines(t.all[hold.idx], y.fit[hold.idx],
         col = "darkorange", lwd = 1.4)
points(t.all[hold.idx], y.fit[hold.idx],
          col = "darkorange", pch = 1, cex = 0.8)
abline(v = t.all[hold.idx[1]], col = "orange", lty = 5, lwd = 1.2)
legend("topleft",
          legend = c("M0 no covariates", "MREG direct regression",
                       "MTF transfer", "held-out observations"),
          col = c("purple", "steelblue", "forest green", "darkorange"),
          lty = 1, pch = c(NA, NA, NA, 1), bty = "n")

diag.M0 = diagnostics(M0)
diag.MREG = diagnostics(MREG)
diag.MTF = diagnostics(MTF)
tab.ex3 = data.frame(
  model = c("M0", "MREG", "MTF"),
  KL = c(diag.M0$m1.KL, diag.MREG$m1.KL, diag.MTF$m1.KL),
  CRPS = c(diag.M0$m1.CRPS, diag.MREG$m1.CRPS, diag.MTF$m1.CRPS),
  PPLC = c(diag.M0$m1.pplc, diag.MREG$m1.pplc, diag.MTF$m1.pplc))

fc.diag.M0 = diagnostics(fc.M0, y = y.holdout)
fc.diag.MREG = diagnostics(fc.MREG, y = y.holdout)
fc.diag.MTF = diagnostics(fc.MTF, y = y.holdout)
tab.ex3.fc = data.frame(
  model = c("M0", "MREG", "MTF"),
  check.loss = c(fc.diag.M0$m1.check_loss,
                   fc.diag.MREG$m1.check_loss,
                   fc.diag.MTF$m1.check_loss),
  CRPS = c(fc.diag.M0$m1.CRPS,
             fc.diag.MREG$m1.CRPS,
             fc.diag.MTF$m1.CRPS))


#####################
#### example 5.4 ####
#####################

Sigma.x = 0.5 ^ as.matrix(dist(1:8))
beta.true = c(3, 1.5, 0, 0, 2, 0, 0, 0)
rhs.ctrl = list(tau0 = 0.15, a_zeta = 2, b_zeta = 9,
                   zeta2_fixed = 9, shrink_intercept = FALSE)
set.seed(20260712)
sim.y = function(X.raw, p0) {
  drop(X.raw %*% beta.true) + 1.5 * (rnorm(nrow(X.raw)) - qnorm(p0))
  }
X.raw = MASS::mvrnorm(160, mu = rep(0, 8), Sigma = Sigma.x)
X = cbind(1, X.raw)
X.hold.raw = MASS::mvrnorm(800, mu = rep(0, 8), Sigma = Sigma.x)
X.hold = cbind(1, X.hold.raw)
ref.hold = drop(X.hold %*% c(0, beta.true))
p.grid = c(0.05, 0.25, 0.50)

y.train = y.hold = M.ldvb = M.mcmc = vector("list", length(p.grid))
for (i in seq_along(p.grid)) {
  p0 = p.grid[i]
  y.train[[i]] = sim.y(X.raw, p0)
  y.hold[[i]] = sim.y(X.hold.raw, p0)
  M.ldvb[[i]] = exalStaticLDVB(
    y = y.train[[i]], X = X, p0 = p0,
    beta_prior = "rhs_ns",
    beta_prior_controls = rhs.ctrl,
    max_iter = ifelse(p0 == 0.05, 420, 260),
    n.samp = 3000, n_samp_xi = 160,
    tol = 1e-4, verbose = FALSE)
  M.mcmc[[i]] = exalStaticMCMC(
    y = y.train[[i]], X = X, p0 = p0,
    beta_prior = "rhs_ns",
    beta_prior_controls = rhs.ctrl,
    n.burn = 2000, n.mcmc = 3000, thin = 1,
    init.from.vb = TRUE,
    verbose = FALSE)
  }

diag.static = Map(function(ldvb, mcmc, y.h) {
  diagnostics(ldvb, mcmc,
                          X = X.hold, y = y.h, ref = ref.hold)
  }, M.ldvb, M.mcmc, y.hold)
y.lim = range(beta.true,
                 unlist(lapply(diag.static, function(z) {
                   c(z$m1.beta.lb[-1], z$m1.beta.ub[-1],
                       z$m2.beta.lb[-1], z$m2.beta.ub[-1])
                   })))
y.lim = y.lim + c(-1, 1) * 0.08 * diff(y.lim)
par(mfrow = c(1, 3), mar = c(5.2, 4.0, 2.6, 1.0), xpd = NA)
for (i in seq_along(p.grid)) {
  plot(diag.static[[i]], type = "coefficients",
         beta.ref = c(0, beta.true),
         include.intercept = FALSE,
         coef.names = c("(Intercept)", paste0("x", seq_along(beta.true))),
         cols = c("orange", "steelblue"),
         legend.labels = c("LDVB 95% interval", "MCMC 95% interval"),
         beta.ref.label = "truth", ylim = y.lim,
         ylab = if (i == 1) "coefficient value" else "",
         main = sprintf("p0 = %.2f", p.grid[i]), legend = i == 1)
  }
