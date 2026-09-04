#!/usr/bin/env Rscript

rm(list = ls(all.names = TRUE))

run.start = proc.time()[["elapsed"]]
options(width = 100, digits = 7)
Sys.setenv(TZ = "America/New_York")

thread.vars = c("OMP_NUM_THREADS", "OMP_THREAD_LIMIT", "OPENBLAS_NUM_THREADS",
                "MKL_NUM_THREADS", "BLIS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS")
for (v in thread.vars) {
  if (!nzchar(Sys.getenv(v))) do.call(Sys.setenv, as.list(setNames("1", v)))
}

RNGversion("4.6.0")
RNGkind("Mersenne-Twister", "Inversion", "Rejection")

for (pkg in c("exdqlm", "coda", "dlm", "MASS")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("Package '%s' is required to run this replication script.", pkg),
         call. = FALSE)
  }
}

suppressPackageStartupMessages(library("exdqlm"))
if (as.character(packageVersion("exdqlm")) != "1.1.1") {
  stop("This replication script requires exdqlm version 1.1.1.", call. = FALSE)
}

options(exdqlm.use_cpp_kf = TRUE,
        exdqlm.use_cpp_builders = FALSE,
        exdqlm.use_cpp_samplers = FALSE,
        exdqlm.use_cpp_postpred = FALSE,
        exdqlm.use_cpp_mcmc = TRUE,
        exdqlm.cpp_mcmc_mode = "fast",
        exdqlm.cpp_threads = 1L)

for (d in c("figures", "tables", "logs")) dir.create(d, showWarnings = FALSE)
unlink(file.path("figures", c("ex1mcmc.png", "ex1quants.png", "ex2quant.png",
                              "ex2checks.png", "ex3data.png",
                              "ex3quantcomps.png", "ex3zetapsi.png",
                              "ex3forecast.png", "ex4static.png")),
       force = TRUE)
unlink(file.path("tables", c("ex2_df_scan_kl.csv", "ex2_dynamic_benchmark.csv",
                             "ex3_diagnostics_summary.csv",
                             "ex3_forecast_metrics.csv",
                             "ex4static_summary.csv")),
       force = TRUE)
unlink(file.path("logs", c("M95-print.txt", "M95-summary.txt",
                           "MTF-median-kt.txt", "sessionInfo.txt")),
       force = TRUE)
if (file.exists("Rplots.pdf")) unlink("Rplots.pdf", force = TRUE)

pdf("Rplots.pdf", width = 7, height = 7, onefile = TRUE)
dev.control(displaylist = "enable")
on.exit({
  while (dev.cur() > 1) dev.off()
}, add = TRUE)

save_current_plot = function(file, width = 7, height = 7) {
  dev.copy(png, filename = file.path("figures", file), width = width,
           height = height, units = "in", res = 220, pointsize = 11,
           type = "cairo")
  dev.off()
  invisible(file.path("figures", file))
}

write_table = function(x, file) {
  write.csv(x, file.path("tables", file), row.names = FALSE)
  invisible(file.path("tables", file))
}

cat("exdqlm JSS replication run\n")
cat(sprintf("R version: %s\n", R.version.string))
cat(sprintf("exdqlm version: %s\n", as.character(packageVersion("exdqlm"))))
cat(sprintf("RNGkind: %s\n", paste(RNGkind(), collapse = ", ")))
cat("Thread environment:\n")
print(Sys.getenv(thread.vars))
cat("exdqlm backend options:\n")
print(options()[c("exdqlm.use_cpp_kf", "exdqlm.use_cpp_builders",
                  "exdqlm.use_cpp_samplers", "exdqlm.use_cpp_postpred",
                  "exdqlm.use_cpp_mcmc", "exdqlm.cpp_mcmc_mode",
                  "exdqlm.cpp_threads")])


## ============================================================================
## 4.1 Lake Huron
## ============================================================================

## --- 
model = polytrendMod(order = 2, m0 = c(579, 0), C0 = 10 * diag(2))

## --- 
set.seed(20260501)
M95 = exdqlmMCMC(y = LakeHuron, p0 = 0.95, model = model, df = 0.9, dim.df = 2,
                 PriorGamma = list(m_gam = -1, s_gam = 0.1, df_gam = 1),
                 n.burn = 2000, n.mcmc = 3000, verbose = FALSE)

M5 = exdqlmMCMC(y = LakeHuron, p0 = 0.05, model = model, df = 0.9, dim.df = 2,
                PriorGamma = list(m_gam = 1, s_gam = 0.1, df_gam = 1),
                n.burn = 2000, n.mcmc = 3000, verbose = FALSE)

## --- 
M95
summary(M95)

## --- 
set.seed(20260616)
M50.trace = exdqlmMCMC(y = LakeHuron, p0 = 0.50, model = model, df = 0.9, dim.df = 2,
                       PriorGamma = list(m_gam = 0, s_gam = 0.1, df_gam = 1),
                       init.from.vb = TRUE,
                       vb_init_controls = list(method = "ldvb", verbose = FALSE),
                       mh.proposal = "slice",
                       n.burn = 7000, n.mcmc = 3000, verbose = FALSE)

## --- Figure 1
par(mfcol = c(2, 2), mar = c(4.1, 4.1, 2.1, 1.0))
keep.idx = seq(1, length(M50.trace$samp.sigma), by = 10)
sigma.trace = coda::mcmc(M50.trace$samp.sigma[keep.idx], thin = 10)
gamma.trace = coda::mcmc(M50.trace$samp.gamma[keep.idx], thin = 10)
coda::traceplot(sigma.trace, main = "sigma trace")
coda::densplot(sigma.trace, main = "sigma density")
coda::traceplot(gamma.trace, main = "gamma trace")
coda::densplot(gamma.trace, main = "gamma density")
save_current_plot("ex1mcmc.png")

## --- 
M50.dqlm = exdqlmMCMC(y = LakeHuron, p0 = 0.50, model = model, df = 0.9, dim.df = 2,
                      gam.init = 0, fix.gamma = TRUE, n.burn = 2000, n.mcmc = 3000,
                      verbose = FALSE)

## --- Figure 2(a)
par(mfrow = c(2, 2), mar = c(4.4, 4.1, 2.2, 1.2), oma = c(0, 0, 0.8, 0))
plot(M95); title("(a) Dynamic quantiles")
plot(M50.dqlm, add = TRUE, col = "steelblue")
plot(M5, add = TRUE, col = "forestgreen")
legend("topright", lty = 1, bty = "n", col = c("purple", "steelblue", "forestgreen"),
       legend = c(expression('p'[0]*'=0.95'), expression('p'[0]*'=0.50'),
                  expression('p'[0]*'=0.05')))

## --- 
fFF = model$FF
fGG = model$GG

plot(LakeHuron,  xlim = c(1952, 1980), ylim = c(575, 582), col = "dark grey",
     main = "(b) Forecasted quantiles", ylab = "forecast 95% CrIs")
fc95 = predict(M95, start.t = length(LakeHuron), k = 8,
               fFF = fFF, fGG = fGG, return.draws = TRUE)
fc50 = predict(M50.dqlm, start.t = length(LakeHuron), k = 8,
               fFF = fFF, fGG = fGG, return.draws = TRUE)
fc05 = predict(M5, start.t = length(LakeHuron), k = 8,
               fFF = fFF, fGG = fGG, return.draws = TRUE)
plot(fc95, add = TRUE)
plot(fc50, add = TRUE, cols = c("steelblue", "light blue"))
plot(fc05, add = TRUE, cols = c("forestgreen", "darkseagreen"))

## --- 
syn.obs = quantileSynthesis( draws_list = list(M5, M50.dqlm, M95), p = c(0.05, 0.50, 0.95),
                             enforce_isotonic = TRUE, rearrange = TRUE, T_expected = length(LakeHuron))

syn.fore = quantileSynthesis(draws_list = list(fc05, fc50, fc95), p = c(0.05, 0.50, 0.95),
                             enforce_isotonic = TRUE, rearrange = TRUE, T_expected = 8)

## --- Figure 2(c)-(d)
synth.obs.col = adjustcolor("#F7D6DE", alpha.f = 0.40)
synth.fore.col = adjustcolor("#D98A9B", alpha.f = 0.38)

plot(syn.obs, y = LakeHuron, time = as.numeric(time(LakeHuron)), xlim = c(1880, 1972),
     ylim = c(575.75,582.25), ylab = "predictive synthesis",
     main = "(c) Observed-period synthesis", show.median = FALSE,
     band.col = synth.obs.col, y.col = adjustcolor("grey30", alpha.f = 0.62))
legend("bottomleft", legend = "Synthesized posterior predictive interval (95%)",
       fill = synth.obs.col, border = NA, bty = "n", cex = 0.68)

plot(syn.obs, y = LakeHuron, time = as.numeric(time(LakeHuron)), xlim = c(1952, 1980),
     ylim = c(575.75,581), ylab = "predictive synthesis",
     main = "(d) Forecast synthesis", show.median = FALSE, band.col = synth.obs.col,
     y.col = adjustcolor("grey30", alpha.f = 0.62))
polygon(c(1972, 1973, 1973, 1972), c(tail(syn.obs$summary$q025, 1),
                                     syn.fore$summary$q025[1], syn.fore$summary$q975[1],
                                     tail(syn.obs$summary$q975, 1)), col = synth.fore.col, border = NA)
plot(syn.fore, time = 1973:1980, add = TRUE, show.median = FALSE,
     band.col = synth.fore.col)
abline(v = 1972, lty = 3)
legend("bottomleft", legend = c("Observed-period synthesis (95%)",
                                "Forecast synthesis (95%)"),
       fill = c(synth.obs.col, synth.fore.col), border = NA, box.lty = 0, 
       bg = adjustcolor("white", alpha.f = 0.86), bty = "o", cex = 0.66)
save_current_plot("ex1quants.png")


## ============================================================================
## 4.2 Sunspots
## ============================================================================

## --- Figure 3 (top)
layout(matrix(c(1, 1, 2, 3), nrow = 2, byrow = TRUE), heights = c(0.9, 1.1))
par(mar = c(3.9, 4.1, 2.6, 1.2) + 0.1)
plot.ts(sunspot.year, col = "dark grey", ylab = "sunspot count", xlab = "year")
title("Sunspot time series")

## --- 
dlm.trend.comp = dlm::dlmModPoly(1, m0 = 50, C0 = 2500)
trend.comp = as.exdqlm(dlm.trend.comp)

seas.comp = seasMod(p = 11, h = 1:4, C0 = 10 * diag(8))

model = trend.comp + seas.comp

## --- 
set.seed(20262601)
M1 = exdqlmLDVB(y = sunspot.year, p0 = 0.85, model = model, df = c(0.9, 0.85),
                dim.df = c(1, 8), dqlm.ind = TRUE, fix.sigma = FALSE,
                sig.init = 2, n.samp = 3000, verbose = FALSE)

set.seed(20262602)
M2 = exdqlmLDVB(y = sunspot.year, p0 = 0.85, model = model, df = c(0.9, 0.85),
                dim.df = c(1, 8), sig.init = 2, fix.sigma = FALSE,
                n.samp = 3000, verbose = FALSE)

## --- Figure 3 (bottom-left)
plot(sunspot.year, xlim = c(1780, 1830), col = "dark grey", ylab = "quantile 95% CrIs")
plot(M1, add = TRUE, col = "red2")
plot(M2, add = TRUE, col = "steelblue")
legend("topleft", lty = 1, bty = "n", col = c("red2", "steelblue"), legend= c("DQLM", "exDQLM"))
title("LDVB fit for p0 = 0.85")

## --- Figure 3 (bottom-right)
hist(M2$samp.gamma, xlab = expression(gamma), main = "",
     col = adjustcolor("#4C72B0", alpha.f = 0.22), border = "#4C72B0")
abline(v = median(M2$samp.gamma), col = "#4C72B0", lwd = 2)
title("exDQLM posterior draws of gamma (p0 = 0.85)")
save_current_plot("ex2quant.png")

## --- Figure 4
par(mfrow = c(2, 3))
diagM1M2 = diagnostics(M1, M2)
plot(diagM1M2, cols = c("red2", "steelblue"))
save_current_plot("ex2checks.png")

## --- 
possible.dfs = cbind(0.9, seq(0.85, 1, 0.05))
possible.dfs

metrics <- matrix(NA_real_, nrow(possible.dfs), 2, dimnames = list(NULL, c("CRPS", "KL")))
for (i in 1:nrow(possible.dfs)) {
  set.seed(20262700 + i)
  temp.M2 = exdqlmLDVB(y = sunspot.year, p0 = 0.85, model = model, df = possible.dfs[i, ],
                       dim.df = c(1, 8), sig.init = 2, fix.sigma = FALSE,
                       n.samp = 3000, verbose = FALSE)
  temp.check = diagnostics(temp.M2)
  metrics[i, ] = c(temp.check$m1.CRPS, temp.check$m1.KL)
}
df.scan = data.frame(possible.dfs, CRPS = metrics[, "CRPS"], KL = metrics[, "KL"])
df.scan.print = round(df.scan, 3)
print(df.scan.print, row.names = FALSE)
write_table(df.scan.print, "ex2_df_scan_kl.csv")

possible.dfs[which.min(metrics[, "CRPS"]), ]

## --- 
set.seed(20262801)
M1mcmc = exdqlmMCMC(y = sunspot.year, p0 = 0.85, model = model, df = c(0.9, 0.85),
                    dim.df = c(1, 8), n.burn = 2000, n.mcmc = 3000, verbose = FALSE,
                    dqlm.ind = TRUE, fix.sigma = FALSE)

set.seed(20262802)
M2mcmc = exdqlmMCMC(y = sunspot.year, p0 = 0.85, model = model, df = c(0.9, 0.85),
                    dim.df = c(1, 8), n.burn = 2000, n.mcmc = 3000, verbose = FALSE,
                    fix.sigma = FALSE)

## --- Table 7
diag.M1 = diagnostics(M1)      
diag.M1mcmc = diagnostics(M1mcmc)  
diag.M2 = diagnostics(M2)      
diag.M2mcmc = diagnostics(M2mcmc) 

table7 = data.frame(
  model   = c("DQLM", "DQLM", "exDQLM", "exDQLM"),
  method  = c("LDVB", "MCMC", "LDVB", "MCMC"),
  runtime = c(as.numeric(M1$run.time), as.numeric(M1mcmc$run.time),
              as.numeric(M2$run.time), as.numeric(M2mcmc$run.time)),
  KL      = c(diag.M1$m1.KL,   diag.M1mcmc$m1.KL,
              diag.M2$m1.KL,   diag.M2mcmc$m1.KL),
  CRPS    = c(diag.M1$m1.CRPS, diag.M1mcmc$m1.CRPS,
              diag.M2$m1.CRPS, diag.M2mcmc$m1.CRPS),
  PPLC    = c(diag.M1$m1.pplc, diag.M1mcmc$m1.pplc,
              diag.M2$m1.pplc, diag.M2mcmc$m1.pplc)
)
table7.print = transform(table7,
                         runtime = round(runtime, 2),
                         KL = round(KL, 3),
                         CRPS = round(CRPS, 3),
                         PPLC = round(PPLC, 1))
print(table7.print, row.names = FALSE)
write_table(table7.print, "ex2_dynamic_benchmark.csv")


## ============================================================================
## 4.3 Big Tree water flow
## ============================================================================

## --- 
data("BTflow", package = "exdqlm")
data("climateIndices", package = "exdqlm")

ex3.dates = seq(as.Date("1987-01-01"), by = "month", length.out = length(BTflow))
flow.df = data.frame(date = ex3.dates, flow = as.numeric(BTflow))
ex3.df = merge(flow.df, climateIndices[, c("date", "noi", "amo")], by = "date")
ex3.df = ex3.df[1:432, ]

y.fit = ts(log(ex3.df$flow), start = c(1987, 1), frequency = 12)
y.train = window(y.fit, end = c(2021, 6))
y.holdout = window(y.fit, start = c(2021, 7))

X.raw = as.matrix(ex3.df[, c("noi", "amo")])
X.train = scale(X.raw[1:414, ])
X.holdout = scale(X.raw[415:432, ], center = attr(X.train, "scaled:center"),
                  scale = attr(X.train, "scaled:scale"))

## -- Figure 5
par(mfrow = c(2, 1), mar = c(3.0, 4.2, 1.0, 0.8), oma = c(1.6, 0, 0, 0))
plot(y.fit, col = "grey35", ylab = "log flow", xlab = "", lwd = 1.1)
grid(col = "grey88")
abline(v = xy.coords(y.fit)$x[414], col = "orange", lty = 5, lwd = 1.2)

plot(NA, xlab = "", ylab = "standardized index", xlim = range(time(y.fit)), ylim = c(-4.3,4) )
lines(as.numeric(time(y.fit)), scale(X.raw[,1]), col ="steelblue", lwd = 1.6, lty = 1)
lines(as.numeric(time(y.fit)), scale(X.raw[,2]), col = "red2", lwd = 1.6, lty = 2)
grid(col = "grey88")
legend(
  "topleft", legend = c("NOI", "AMO"), col = c("steelblue","red2"),
  lty = c(1,2), lwd = 1.6, bty = "n", ncol = 2
)
abline(v = xy.coords(y.fit)$x[414], col = "orange", lty = 5, lwd = 1.2)
mtext("time", side = 1, outer = TRUE, line = 0.4)
save_current_plot("ex3data.png")

## --- 
trend.comp = polytrendMod(1, m0 = log(50), C0 = 1)
seas.comp = seasMod(p = 12, h = c(1, 2, 0.1469118636), C0 = diag(1, 6))
model = trend.comp + seas.comp

## --- 
lambda.grid = c(0.70, 0.75, 0.80, 0.85, 0.90, 0.95, 0.99)
old.opt = options(exdqlm.max_iter = 600L)
pplc.grid = rep(NA_real_, length(lambda.grid))
for (i in seq_along(lambda.grid)) {
  set.seed(20264001 + i)
  temp.MTF = exdqlmTransferLDVB(y = y.train, p0 = 0.15, model = model, df = c(0.99, 0.99),
                                dim.df = c(1, 6), X = X.train, tf.df = c(0.99, 1), lam = lambda.grid[i],
                                tf.m0 = rep(0, 3), tf.C0 = diag(c(0.1, 1, 1), 3), sig.init = 0.1,
                                gam.init = -0.1, n.samp = 1000, tol = 0.05, verbose = FALSE)
  temp.diag = diagnostics(temp.MTF)
  pplc.grid[i] = temp.diag$m1.pplc
}
lambda.star = lambda.grid[which.min(pplc.grid)]
lambda.star

## --- 
set.seed(20264101)
M0 = exdqlmLDVB(y = y.train, p0 = 0.15, model = model, df = c(0.99, 0.99),
                dim.df = c(1, 6), sig.init = 0.1, gam.init = -0.1,
                n.samp = 1000, tol = 0.05, verbose = FALSE)

reg.comp = regMod(X.train, m0 = rep(0, 2), C0 = diag(1, 2))
set.seed(20264301)
MREG = exdqlmLDVB(y = y.train, p0 = 0.15, model = model + reg.comp, df = c(0.99, 0.99, 1),
                  dim.df = c(1, 6, 2), sig.init = 0.1, gam.init = -0.1,
                  n.samp = 1000, tol = 0.05, verbose = FALSE)

set.seed(20264201)
MTF = exdqlmTransferLDVB(y = y.train, p0 = 0.15, model = model, df = c(0.99, 0.99),
                         dim.df = c(1, 6), X = X.train, tf.df = c(0.99, 1), lam = lambda.star,
                         tf.m0 = rep(0, 3), tf.C0 = diag(c(0.1, 1, 1), 3), sig.init = 0.1,
                         gam.init = -0.1, n.samp = 1000, tol = 0.05, verbose = FALSE)
options(old.opt)

## --- Figure 6 (top)
par(mfrow = c(3, 1), mar = c(2.8, 4.4, 1.0, 0.9), oma = c(1.8, 0, 0, 0))
plot(y.train, col = "grey", ylim = c(1, 8), xlim = c(2016, 2020),
     ylab = "log flow / quantile")
grid(col = "grey90")
plot(M0, add = TRUE)
plot(MREG, add = TRUE, col = "steelblue")
plot(MTF, add = TRUE, col = "forestgreen")
legend("topleft", legend = c("M0 no covariates", "MREG direct regression",
                             "MTF transfer function"), col = c("purple", "steelblue", "forestgreen"),
       lty = 1, lwd = 1.5, bty = "n")

## --- Figure 6 (middle)
plot(NA, ylim = c(-2, 2), xlim = c(2016, 2020), ylab = "seasonal components")
grid(col = "grey90")
plot(M0, type = "component", index = 2:7, add = TRUE)
plot(MREG, type = "component", index = 2:7, add = TRUE, col = "steelblue")
plot(MTF, type = "component", index = 2:7, add = TRUE, col = "forestgreen")
abline(h = 0, col = "orange", lty = 3, lwd = 1.4)

## --- Figure 6 (bottom)
plot(NA, ylim = c(-2.5, 3), xlim = c(2016, 2020), ylab = "covariate contribution")
grid(col = "grey90")
plot(MREG, type = "component", index = 8:9, add = TRUE, col = "steelblue")
plot(MTF, type = "component", index = 8, add = TRUE, col = "forestgreen")
abline(h = 0, col = "orange", lty = 3, lwd = 1.4)
legend("topleft", legend = c("MREG direct", "MTF transfer"),
       col = c("steelblue", "forestgreen"), lty = 1, lwd = 1.5, bty = "n")
save_current_plot("ex3quantcomps.png")

## --- Figure 7
layout(matrix(c(1, 1, 2, 3), nrow = 2, byrow = TRUE))
plot(MTF, type = "state", index = 8, col = "forestgreen", add = FALSE)
grid(col = "grey90")
abline(h = 0, col = "orange", lty = 3, lwd = 1.4)
title(expression(zeta[t]))

par(mar = c(3.8, 4.2, 2.1, 0.8))
plot(y.train, type = "n", ylim = c(-0.11, 0.01), xlab = "time", ylab = "component CrIs")
plot(MTF, type = "state", index = 9, col = "steelblue", add = TRUE)
grid(col = "grey90")
abline(h = 0, col = "orange", lty = 3, lwd = 1.4)
title(expression(psi[list(NOI, t)]))

plot(y.train, type = "n", ylim = c(-0.015, 0.020), xlab = "time", ylab = "component CrIs")
plot(MTF, type = "state", index = 10, col = "darkorange", add = TRUE)
grid(col = "grey90")
abline(h = 0, col = "orange", lty = 3, lwd = 2)
title(expression(psi[list(AMO, t)]))
save_current_plot("ex3zetapsi.png")

## --- 
MTF$median.kt
writeLines(capture.output(MTF$median.kt), file.path("logs", "MTF-median-kt.txt"))

## --- 
k.fore = length(y.holdout)

F0.future = model$FF
G0.future = model$GG
fc.M0 = predict(M0, start.t = length(y.train), k = k.fore, fFF = F0.future,
                fGG = G0.future, return.draws = TRUE, n.samp = 1000, seed = 20265101)

n.x = ncol(X.holdout)
reg.future = regMod(X.holdout, m0 = rep(0, n.x), C0 = diag(1, n.x))
model.reg.future = model + reg.future
FREG.future = model.reg.future$FF
GREG.future = model.reg.future$GG
fc.MREG = predict(MREG, start.t = length(y.train), k = k.fore, fFF = FREG.future,
                  fGG = GREG.future, return.draws = TRUE, n.samp = 1000, seed = 20265301)

n.state = length(model$m0)
FTF.future = matrix(0, nrow = n.state + n.x + 1, ncol = k.fore)
FTF.future[seq_len(n.state), ] = F0.future
FTF.future[n.state + 1, ] = 1
GTF.future = array(0, c(n.state + n.x + 1, n.state + n.x + 1, k.fore))
GTF.future[seq_len(n.state), seq_len(n.state), ] = G0.future
zeta.ind = n.state + 1
psi.ind = n.state + 1 + seq_len(n.x)
GTF.future[zeta.ind, zeta.ind, ] = lambda.star
for (j in seq_len(n.x)) {
  GTF.future[zeta.ind, psi.ind[j], ] = X.holdout[, j]
  GTF.future[psi.ind[j], psi.ind[j], ] = 1
}
fc.MTF = predict(MTF, start.t = length(y.train), k = k.fore, fFF = FTF.future,
                 fGG = GTF.future, return.draws = TRUE, n.samp = 1000, seed = 20265201)

## --- Figure 8
plot(y.fit, col = "grey70", xlim = c(2020, 2023), ylim = c(1,8),
     ylab = "log flow / forecast quantile", xlab = "time")
grid(col = "grey90")
plot(fc.M0, add = TRUE, cols = c("purple", "plum"))
plot(fc.MREG, add = TRUE, cols = c("steelblue", "lightblue"))
plot(fc.MTF, add = TRUE, cols = c("forestgreen", "darkseagreen"))
t.all = as.numeric(time(y.fit))
hold.idx = 415:432
lines(t.all[hold.idx], y.fit[hold.idx], col = "darkorange", lwd = 1.4)
points(t.all[hold.idx], y.fit[hold.idx], col = "darkorange", pch = 1, cex = 0.8)
abline(v = t.all[hold.idx[1]], col = "orange", lty = 5, lwd = 1.2)
legend("topleft", legend = c("M0 no covariates", "MREG direct regression",
                             "MTF transfer", "held-out observations"),
       col = c("purple", "steelblue", "forestgreen", "darkorange"),
       lty = 1, pch = c(NA, NA, NA, 1), bty = "n")
save_current_plot("ex3forecast.png")

## --- Table 8
diag.M0 = diagnostics(M0)
diag.MREG = diagnostics(MREG)
diag.MTF = diagnostics(MTF)
tab.ex3 = data.frame(model = c("M0", "MREG", "MTF"),
                     KL = c(diag.M0$m1.KL, diag.MREG$m1.KL, diag.MTF$m1.KL),
                     CRPS = c(diag.M0$m1.CRPS, diag.MREG$m1.CRPS, diag.MTF$m1.CRPS),
                     PPLC = c(diag.M0$m1.pplc, diag.MREG$m1.pplc, diag.MTF$m1.pplc))
tab.ex3.print = transform(tab.ex3, KL = round(KL, 3), CRPS = round(CRPS, 3),
                          PPLC = round(PPLC, 1))
print(tab.ex3.print, row.names = FALSE)
write_table(tab.ex3.print, "ex3_diagnostics_summary.csv")

## --- Table 9
fc.diag.M0 = diagnostics(fc.M0, y = y.holdout)
fc.diag.MREG = diagnostics(fc.MREG, y = y.holdout)
fc.diag.MTF = diagnostics(fc.MTF, y = y.holdout)
tab.ex3.fc = data.frame(model = c("M0", "MREG", "MTF"),
                        check.loss = c(fc.diag.M0$m1.check_loss, fc.diag.MREG$m1.check_loss,
                                       fc.diag.MTF$m1.check_loss),
                        CRPS = c(fc.diag.M0$m1.CRPS, fc.diag.MREG$m1.CRPS, fc.diag.MTF$m1.CRPS))
tab.ex3.fc.print = transform(tab.ex3.fc, check.loss = round(check.loss, 3),
                             CRPS = round(CRPS, 3))
print(tab.ex3.fc.print, row.names = FALSE)
write_table(tab.ex3.fc.print, "ex3_forecast_metrics.csv")


## ============================================================================
## 4.4 Static exAL regression on a simulated sparse Gaussian benchmark
## ============================================================================

Sigma.x = 0.5 ^ as.matrix(dist(1:8))
beta.true = c(3, 1.5, 0, 0, 2, 0, 0, 0)
rhs.ctrl = list(tau0 = 0.15, zeta2_fixed = 9,
                shrink_intercept = FALSE)

set.seed(20260712)
sim.y = function(X.raw, p0) {
  drop(X.raw %*% beta.true) + 1.5 * (rnorm(nrow(X.raw)) - qnorm(p0))}

X.raw = MASS::mvrnorm(160, mu = rep(0, 8), Sigma = Sigma.x)
X = cbind(1, X.raw)
X.hold.raw = MASS::mvrnorm(800, mu = rep(0, 8), Sigma = Sigma.x)
X.hold = cbind(1, X.hold.raw)
ref.hold = drop(X.hold %*% c(0, beta.true))
p.grid = c(0.05, 0.25, 0.50)

## --- 
y.train = y.hold = M.ldvb = M.mcmc = vector("list", length(p.grid))
for (i in seq_along(p.grid)) {
  p0 = p.grid[i]
  y.train[[i]] = sim.y(X.raw, p0)
  y.hold[[i]] = sim.y(X.hold.raw, p0)
  M.ldvb[[i]] = exalStaticLDVB(y = y.train[[i]], X = X, p0 = p0,
                               beta_prior = "rhs_ns", beta_prior_controls = rhs.ctrl,
                               max_iter = ifelse(p0 == 0.05, 420, 260),
                               n.samp = 3000, tol = 1e-4, verbose = FALSE)
  M.mcmc[[i]] = exalStaticMCMC(y = y.train[[i]], X = X, p0 = p0,
                               beta_prior = "rhs_ns", beta_prior_controls = rhs.ctrl,
                               n.burn = 2000, n.mcmc = 3000, thin = 1,
                               init.from.vb = TRUE, verbose = FALSE)}

## --- Figure 9
diag.static = Map(function(ldvb, mcmc, y.h) {
  diagnostics(ldvb, mcmc, X = X.hold, y = y.h, ref = ref.hold)
}, M.ldvb, M.mcmc, y.hold)

y.lim = range(beta.true,
              unlist(lapply(diag.static, function(z){
                c(z$m1.beta.lb[-1], z$m1.beta.ub[-1], z$m2.beta.lb[-1],
                  z$m2.beta.ub[-1])})))
y.lim = y.lim + c(-1, 1) * 0.08 * diff(y.lim)

par(mfrow = c(1, 3), mar = c(5.2, 4.0, 2.6, 1.0), xpd = NA)
for (i in seq_along(p.grid)) {plot(diag.static[[i]], type = "coefficients",
                                   beta.ref = c(0, beta.true), include.intercept = FALSE,
                                   coef.names = c("(Intercept)", paste0("x", seq_along(beta.true))),
                                   cols = c("orange", "steelblue"), legend.labels = c("LDVB 95% interval",
                                                                                      "MCMC 95% interval"), beta.ref.label = "truth", ylim = y.lim,
                                   ylab = if (i == 1) "coefficient value" else "",
                                   main = sprintf("p0 = %.2f", p.grid[i]), legend = i == 1)}
save_current_plot("ex4static.png")

## --- Table 10

active.idx = which(beta.true != 0) + 1   
null.idx   = which(beta.true == 0) + 1

table10 = data.frame(p0 = numeric(0), method = character(0), runtime = numeric(0),
                     active.rmse = numeric(0), null.mae = numeric(0),
                     holdout.qrmse = numeric(0), stringsAsFactors = FALSE)

for (i in seq_along(p.grid)) {
  p0 = p.grid[i]
  diag.i = diag.static[[i]]
  
  beta.m1 = diag.i$m1.beta.mean
  beta.m2 = diag.i$m2.beta.mean
  
  active.rmse.m1 = sqrt(mean((beta.m1[active.idx] - beta.true[beta.true != 0])^2))
  null.mae.m1    = mean(abs(beta.m1[null.idx]))
  active.rmse.m2 = sqrt(mean((beta.m2[active.idx] - beta.true[beta.true != 0])^2))
  null.mae.m2    = mean(abs(beta.m2[null.idx]))
  
  qrmse.m1 = diag.i$m1.ref_rmse
  qrmse.m2 = diag.i$m2.ref_rmse
  
  table10 = rbind(table10,
                  data.frame(p0 = p0, method = "LDVB", runtime = as.numeric(M.ldvb[[i]]$run.time),
                             active.rmse = active.rmse.m1, null.mae = null.mae.m1,
                             holdout.qrmse = qrmse.m1),
                  data.frame(p0 = p0, method = "MCMC", runtime = as.numeric(M.mcmc[[i]]$run.time),
                             active.rmse = active.rmse.m2, null.mae = null.mae.m2,
                             holdout.qrmse = qrmse.m2))
}
table10.print = transform(table10,
                          runtime = round(runtime, 2),
                          active.rmse = round(active.rmse, 3),
                          null.mae = round(null.mae, 3),
                          holdout.qrmse = round(holdout.qrmse, 3))
print(table10.print, row.names = FALSE)
write_table(table10.print, "ex4static_summary.csv")

writeLines(capture.output(M95), file.path("logs", "M95-print.txt"))
writeLines(capture.output(summary(M95)), file.path("logs", "M95-summary.txt"))

cat("\n== sessionInfo() ==\n")
session.info = capture.output(sessionInfo())
cat(paste(session.info, collapse = "\n"), "\n")
writeLines(session.info, file.path("logs", "sessionInfo.txt"))

cat(sprintf("\nTotal elapsed seconds: %.3f\n", proc.time()[["elapsed"]] - run.start))
