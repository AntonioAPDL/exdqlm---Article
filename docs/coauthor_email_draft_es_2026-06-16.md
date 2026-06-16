# Draft Email To Raquel Prado And Bruno

Asunto: Revisión final del artículo de `exdqlm` para reenvío a JSS

Buenas tardes, Raquel y Bruno,

Ya terminé de implementar la revisión completa después del rechazo editorial de JSS. Hice cambios en el artículo, el appendix, el paquete y los materiales de reproducibilidad.

Para facilitarles la revisión, preparé una versión marcada del manuscrito:

`exdqlm-jss-coauthor-review.pdf`

Esa versión tiene cajas azules indicando las partes principales que cambiaron. Ojo: Overleaf probablemente abre/compila por defecto la versión limpia `exdqlm-jss.tex`, y por eso ahí no aparecen las cajas azules. Para ver los comentarios de revisión hay que abrir directamente `exdqlm-jss-coauthor-review.pdf` o compilar `exdqlm-jss-coauthor-review.tex`. También dejé una guía rápida en:

`00_COAUTHOR_REVIEW_README.md`

La versión limpia para enviar sigue siendo:

`exdqlm-jss.pdf`

Los cambios principales son:

- Reorganicé la introducción para dejar más claro qué parte viene de la metodología previa y cuál es la contribución de software de este artículo.
- Agregué una sección nueva de package design and implementation, con las clases, métodos, objetos devueltos, backends y el workflow general del paquete.
- Actualicé el paquete a la versión `1.1.0`, con una estructura S3 más clara: `print()`, `summary()`, `plot()`, `predict()`, objetos de diagnostics/forecast diagnostics visibles, y clases comunes como `exdqlmFit` y `exalStaticFit`.
- Actualicé los code chunks del artículo para que sigan la API nueva y estén alineados con `code.R`.
- En Example 3, los forecasts ahora usan el workflow estándar con `predict()`, y las métricas del holdout usan `exdqlmForecastDiagnostics()`.
- En Example 4, la figura de intervalos de coeficientes ahora se genera usando `exalStaticDiagnostics()` y `plot(..., type = "coefficients")`, en vez de código manual.
- El supplement anterior ahora está incluido como appendices dentro del PDF principal, como pidió el editor. Ya no hay un PDF suplementario separado.
- Limpié los replication materials para que sean un archivo standalone sin depender de Git. El workflow público ahora es simplemente `Rscript code.R`, con opciones `--quick` y `--example`.
- Preparé también el `response-to-editor.pdf` con la respuesta punto por punto.

También dejé un resumen más detallado en:

`docs/coauthor_resubmission_summary_2026-06-16.md`

Lo que les pediría revisar es principalmente:

1. si el framing de la contribución les parece correcto;
2. si la nueva sección de package design está clara;
3. si Examples 3 y 4 se leen bien con la nueva API;
4. si el appendix integrado al PDF principal les parece razonable;
5. si el `response-to-editor.pdf` responde bien a cada comentario de JSS.

En cuanto a verificaciones, corrí los checks con R 4.6.0 y `exdqlm` 1.1.0. El manuscrito limpio compila, la versión marcada compila, `Rscript code.R --quick` pasa, el strict reproducibility preflight pasa con 0 errors y 0 warnings, y el replication archive también pasa desde una extracción nueva sin Git.

Los archivos que planeo subir son:

- `exdqlm-jss.pdf`
- `exdqlm_1.1.0.tar.gz`
- `exdqlm-jss-replication.tar.gz`
- `response-to-editor.pdf`

Si les parece bien después de esta revisión, creo que ya estaríamos listos para reenviar a JSS.

Gracias,
Antonio
