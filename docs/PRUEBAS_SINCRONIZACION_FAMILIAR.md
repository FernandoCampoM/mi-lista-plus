# Pruebas pendientes · Sincronización familiar (Fase 1)

Estado al 6 de octubre de 2026. Rama `feature/sincronizacion-familiar`, PR #2.

## Ya probado

- [x] Firebase configurado: Authentication con correo/contraseña, cuenta del hogar creada y reglas publicadas.
- [x] Pruebas con **un solo celular** (celular principal de Fernando): acceso oculto, activación y sincronización básica.

## Antes de probar en otro celular

1. **Respaldo en cada celular**: *Respaldo y sincronización → CREAR Y GUARDAR RESPALDO*.
2. **Instalar la versión de esta rama** en el celular:
   - Activar *Opciones de desarrollador → Depuración inalámbrica* y pasar la IP:puerto (y el código de vinculación si lo pide).
   - Si el celular tiene la app de Play Store, hay que **desinstalarla primero** (la firma es distinta) — **se borran sus datos locales**, por eso el respaldo del paso 1.
3. ⚠️ Esta versión actualiza la base de datos local (v2 → v3). Volver a una versión anterior exige desinstalar.
4. Compilar desde esta PC requiere: `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\tmp` (Java 20 falla con la carpeta temporal del usuario).

## Pendiente: segundo celular de Fernando (celular B)

| # | Qué hacer | Resultado esperado | ✔ |
|---|---|---|---|
| 10 | En B: tocar 7 veces "Datos incluidos" → activar como **Fernando** | Respaldo automático; el inventario de B queda **igual al del principal** y aparecen tus ventas y clientes | ☐ |
| 11 | Vender en el principal con la app abierta en B | En unos segundos baja el stock en B y aparece la venta | ☐ |
| 12 | Cambiar una cantidad en el inventario de B | Se refleja en el principal | ☐ |
| 13 | Abrir el editor de inventario en el principal (sin guardar) → vender 1 unidad de un producto en B → guardar el editor en el principal **sin tocar ese producto** | La venta de B **se respeta** (el stock no vuelve al valor anterior) | ☐ |
| 13b | Editar o cancelar en B una venta hecha en el principal | El cambio aparece en el principal | ☐ |

## Pendiente: celular de la esposa

| # | Qué hacer | Resultado esperado | ✔ |
|---|---|---|---|
| 14 | Activar como **Esposa** | Mismo inventario que Fernando; **sin** las ventas ni los clientes de Fernando | ☐ |
| 15 | Ella registra una venta | El stock baja en **todos** los celulares; la venta **no** aparece en los de Fernando | ☐ |
| 15b | Ella crea un cliente | No aparece en los celulares de Fernando | ☐ |

## Pendiente: casos límite

| # | Qué hacer | Resultado esperado | ✔ |
|---|---|---|---|
| 16 | Poner dos celulares en modo avión, vender la **última unidad** del mismo producto en ambos y quitar el modo avión | En *Sincronización familiar* aparece la alerta de **stock negativo** | ☐ |
| 17 | En un celular: **DESACTIVAR EN ESTE CELULAR** | Deja de enviar/recibir; sus datos locales se conservan; reactivar pide la contraseña | ☐ |
| 18 | Vender sin internet en B, cerrar la app, abrirla con internet | La venta sube sola (la pantalla de sincronización dice "No hay cambios pendientes") | ☐ |
| 19 | Importar un respaldo con **REEMPLAZAR** (inventario) con la sincronización activa | Bloqueado con el mensaje "Usa COMBINAR" | ☐ |

## Si algo falla

Anotar el **número de la prueba**, qué se esperaba y qué pasó. Con el celular conectado por depuración inalámbrica se pueden leer los registros (`mi_lista_plus.sync`) mientras se repite la prueba.

## Limitaciones conocidas (Fase 1)

- El vendedor no se puede cambiar después de activar.
- Seguimientos, notas y simulaciones siguen siendo locales de cada celular (Fase 2).
- Una venta de la misma unidad en dos celulares sin internet deja stock negativo; se corrige a mano en el inventario.
