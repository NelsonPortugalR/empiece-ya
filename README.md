# Dashboard Empiece Ya!

Dashboard analítico de los ganadores del **Programa Empiece Ya!** de Rena Ware:
cuántos hay en el tiempo, por organización (código de división, ej. `WV08`),
por período (cierres cada 2 semanas, 26 por año) y por año. Incluye buscador
por nombre, premios acumulados por asesor, comparador y tabla pivote.

- `public/index.html` — el dashboard completo, un solo archivo y sin librerías externas
- `public/_headers`, `public/404.html` — configuración
- `wrangler.toml` — dice que el sitio son los archivos de `public/`

## Cómo se publica

El sitio es estático: no hay build ni dependencias. Cloudflare está conectado
a este repositorio, así que **cada push a `main` publica** en
https://empiece-ya.nelson1614.workers.dev. No hay que subir ningún archivo a mano.

La conexión se hizo una sola vez (20/10/2026), en Cloudflare → Workers & Pages →
`empiece-ya` → Settings → Builds → Connect: este repo, rama `main`, sin
comando de build. El nombre que lleva el `wrangler.toml` es el del Worker que
ya existía, así que **el link no cambia**.

## De dónde salen los datos

El HTML no trae datos. Al entrar pide la clave de administrador (la misma del
panel admin) y lee todo de Supabase (proyecto `kiexpdaaoegbtesqmaff`) con la
clave pública. Lo que se puede leer lo deciden las funciones de la base, no el HTML:

- `admin_login(p_clave)` da el token de sesión y `eya_dashboard(p_token)`
  devuelve todos los datos en un JSON. Sin token válido responde «Sesion invalida».
- `eya_periodos` — un cierre (PB) por fila, con estado `Historico`, `Oficial` o `Preliminar`
- `eya_historico` — los ganadores hasta el PB09 de 2026
- `eya_premios` — un premio por fila y por PB desde el PB10 de 2026. Es
  acumulativo: la misma persona puede volver a salir en otro PB con otro premio
- `eya_asesores` — vista con cada asesor **una sola vez**, con la fecha de su primera calificación
- `eya_items`, `eya_item_alias` — el catálogo de premios y cómo se reconoce cada uno en el texto del PDF

Por eso **un PB nuevo no requiere tocar este repo**: se carga en la base y el
dashboard lo muestra al recargar.

## Cargar un PB nuevo

Cada cierre llega el PDF «Resultados Programa Eya! - PBxx». Se carga con
`eya_cargar_pb(p_token, p_anio, p_pb, p_fecha, p_estado, p_filas, p_fuente)`
—o `eya_cargar_pb_interno(...)` desde SQL—, donde cada fila de `p_filas` es
`[codigo, nombre, division, premio]`. Reglas que aplica la base:

- un PB `Oficial` no se vuelve a cargar; un `Preliminar` se reemplaza cuando llega el oficial
- cada asesor cuenta una sola vez, con su primera calificación
- los premios se normalizan con `eya_item_alias`; si aparece uno nuevo, se agrega ahí

## Antes de tocar el código

- `public/index.html` es lo que se publica: los cambios se hacen sobre él y se
  prueban en un navegador antes del push.
- No usa librerías por CDN a propósito: los gráficos son SVG propios. Con
  Chart.js por CDN el dashboard llegó a no mostrar los gráficos.
