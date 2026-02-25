# Módulo de Órdenes de Trabajo y Materiales

## Contexto
El repositorio actual no contiene código de la app (solo `.gitkeep`). Por eso se crea una base de módulo alineada al dominio de activos/items para poder integrarlo cuando exista el frontend/backend principal.

## Objetivo
Agregar la parte de **orden de trabajo** con:
- Ciclo de vida de la OT.
- Relación con activo/item.
- Materiales requeridos y consumidos.
- Mano de obra/servicios.
- Costeo total.
- Trazabilidad por estados y auditoría básica.

## Entidades propuestas

### 1) work_orders
Cabecera de la orden de trabajo.

Campos clave:
- `work_order_number`: consecutivo único visible para el usuario.
- `asset_item_code`: referencia al item/activo intervenido.
- `type`: correctivo, preventivo, inspección, mejora.
- `priority`: baja, media, alta, crítica.
- `status`: borrador, aprobada, en_progreso, en_pausa, completada, cancelada.
- `reported_by`, `assigned_to`: responsables.
- `planned_start_at`, `planned_end_at`, `actual_start_at`, `actual_end_at`.
- `estimated_cost`, `actual_cost`.

### 2) work_order_materials
Detalle de materiales por OT.

Campos clave:
- `material_item_code`: código de item de inventario.
- `description`, `uom`.
- `qty_planned`, `qty_issued`, `qty_returned`, `qty_consumed`.
- `unit_cost`, `line_cost`.
- `warehouse_code`.

Regla:
`qty_consumed = qty_issued - qty_returned`.

### 3) work_order_labor
Detalle de horas y costos de mano de obra/servicios.

Campos clave:
- `technician_code`.
- `hours`.
- `hourly_rate`.
- `line_cost`.
- `external_vendor`.

### 4) work_order_status_history
Bitácora de cambios de estado.

Campos clave:
- `from_status`, `to_status`.
- `changed_by`, `changed_at`.
- `comment`.

## Flujo sugerido
1. Crear OT en `borrador`.
2. Aprobar (`aprobada`).
3. Iniciar ejecución (`en_progreso`) y emitir materiales.
4. Registrar mano de obra y devoluciones.
5. Cerrar (`completada`) calculando costo real.
6. Si aplica, cancelar (`cancelada`) con motivo.

## Validaciones de negocio mínimas
- No permitir `completada` sin `actual_start_at` y `actual_end_at`.
- No permitir materiales con cantidades negativas.
- No permitir cerrar OT sin al menos una acción (material o labor o comentario técnico).
- `actual_cost = SUM(materiales.line_cost) + SUM(labor.line_cost)`.

## Endpoints recomendados (REST)
- `POST /work-orders`
- `GET /work-orders`
- `GET /work-orders/{id}`
- `PATCH /work-orders/{id}`
- `POST /work-orders/{id}/status`
- `POST /work-orders/{id}/materials`
- `PATCH /work-orders/{id}/materials/{materialId}`
- `POST /work-orders/{id}/labor`
- `POST /work-orders/{id}/close`

## Integración con módulo de activos/items
- `asset_item_code` debe existir en catálogo de activos/items.
- `material_item_code` debe existir en catálogo de inventario/items.
- Costos de material pueden inicializarse desde costo promedio del item.

## Próximo paso recomendado
Cuando se incluya el código de la app actual, mapear estas tablas al stack existente (ORM/modelos/controladores) siguiendo el patrón ya usado por `item/activo`.
