-- PostgreSQL schema base para módulo de órdenes de trabajo

CREATE TABLE IF NOT EXISTS work_orders (
    id BIGSERIAL PRIMARY KEY,
    work_order_number VARCHAR(30) NOT NULL UNIQUE,
    asset_item_code VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    type VARCHAR(20) NOT NULL CHECK (type IN ('correctivo', 'preventivo', 'inspeccion', 'mejora')),
    priority VARCHAR(10) NOT NULL DEFAULT 'media' CHECK (priority IN ('baja', 'media', 'alta', 'critica')),
    status VARCHAR(20) NOT NULL DEFAULT 'borrador' CHECK (status IN ('borrador', 'aprobada', 'en_progreso', 'en_pausa', 'completada', 'cancelada')),
    reported_by VARCHAR(100),
    assigned_to VARCHAR(100),
    planned_start_at TIMESTAMPTZ,
    planned_end_at TIMESTAMPTZ,
    actual_start_at TIMESTAMPTZ,
    actual_end_at TIMESTAMPTZ,
    estimated_cost NUMERIC(14,2) NOT NULL DEFAULT 0,
    actual_cost NUMERIC(14,2) NOT NULL DEFAULT 0,
    cancellation_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS work_order_materials (
    id BIGSERIAL PRIMARY KEY,
    work_order_id BIGINT NOT NULL REFERENCES work_orders(id) ON DELETE CASCADE,
    material_item_code VARCHAR(50) NOT NULL,
    description VARCHAR(250),
    uom VARCHAR(20) NOT NULL,
    warehouse_code VARCHAR(30),
    qty_planned NUMERIC(14,4) NOT NULL DEFAULT 0 CHECK (qty_planned >= 0),
    qty_issued NUMERIC(14,4) NOT NULL DEFAULT 0 CHECK (qty_issued >= 0),
    qty_returned NUMERIC(14,4) NOT NULL DEFAULT 0 CHECK (qty_returned >= 0),
    qty_consumed NUMERIC(14,4) GENERATED ALWAYS AS (qty_issued - qty_returned) STORED,
    unit_cost NUMERIC(14,4) NOT NULL DEFAULT 0 CHECK (unit_cost >= 0),
    line_cost NUMERIC(14,2) GENERATED ALWAYS AS ((qty_issued - qty_returned) * unit_cost) STORED,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (qty_returned <= qty_issued)
);

CREATE TABLE IF NOT EXISTS work_order_labor (
    id BIGSERIAL PRIMARY KEY,
    work_order_id BIGINT NOT NULL REFERENCES work_orders(id) ON DELETE CASCADE,
    technician_code VARCHAR(50),
    external_vendor VARCHAR(120),
    description VARCHAR(250),
    hours NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (hours >= 0),
    hourly_rate NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (hourly_rate >= 0),
    line_cost NUMERIC(14,2) GENERATED ALWAYS AS (hours * hourly_rate) STORED,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS work_order_status_history (
    id BIGSERIAL PRIMARY KEY,
    work_order_id BIGINT NOT NULL REFERENCES work_orders(id) ON DELETE CASCADE,
    from_status VARCHAR(20),
    to_status VARCHAR(20) NOT NULL,
    changed_by VARCHAR(100),
    comment TEXT,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_work_orders_updated_at ON work_orders;
CREATE TRIGGER trg_work_orders_updated_at
BEFORE UPDATE ON work_orders
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_work_order_materials_updated_at ON work_order_materials;
CREATE TRIGGER trg_work_order_materials_updated_at
BEFORE UPDATE ON work_order_materials
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE FUNCTION recalculate_work_order_actual_cost(p_work_order_id BIGINT)
RETURNS VOID AS $$
DECLARE
    material_total NUMERIC(14,2);
    labor_total NUMERIC(14,2);
BEGIN
    SELECT COALESCE(SUM(line_cost), 0)
      INTO material_total
      FROM work_order_materials
     WHERE work_order_id = p_work_order_id;

    SELECT COALESCE(SUM(line_cost), 0)
      INTO labor_total
      FROM work_order_labor
     WHERE work_order_id = p_work_order_id;

    UPDATE work_orders
       SET actual_cost = material_total + labor_total,
           updated_at = NOW()
     WHERE id = p_work_order_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_recalculate_cost_from_materials()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM recalculate_work_order_actual_cost(COALESCE(NEW.work_order_id, OLD.work_order_id));
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_recalculate_cost_from_labor()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM recalculate_work_order_actual_cost(COALESCE(NEW.work_order_id, OLD.work_order_id));
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_materials_recalculate_cost ON work_order_materials;
CREATE TRIGGER trg_materials_recalculate_cost
AFTER INSERT OR UPDATE OR DELETE ON work_order_materials
FOR EACH ROW
EXECUTE FUNCTION trg_recalculate_cost_from_materials();

DROP TRIGGER IF EXISTS trg_labor_recalculate_cost ON work_order_labor;
CREATE TRIGGER trg_labor_recalculate_cost
AFTER INSERT OR UPDATE OR DELETE ON work_order_labor
FOR EACH ROW
EXECUTE FUNCTION trg_recalculate_cost_from_labor();
