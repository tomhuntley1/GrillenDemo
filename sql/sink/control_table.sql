IF OBJECT_ID('dbo.pipeline_control', 'U') IS NOT NULL DROP TABLE dbo.pipeline_control;
CREATE TABLE dbo.pipeline_control (
    control_id    INT IDENTITY(1,1) NOT NULL,
    source_schema NVARCHAR(50)      NOT NULL,
    source_table  NVARCHAR(100)     NOT NULL,
    sink_schema   NVARCHAR(50)      NOT NULL,
    sink_table    NVARCHAR(100)     NOT NULL,
    is_active     BIT               NOT NULL DEFAULT 1,
    load_order    INT               NOT NULL DEFAULT 1,
    CONSTRAINT PK_pipeline_control PRIMARY KEY (control_id)
);

INSERT INTO dbo.pipeline_control (source_schema, source_table, sink_schema, sink_table, load_order)
VALUES
    ('erp', 'warehouses',      'brz', 'warehouses',      1),
    ('erp', 'customers',       'brz', 'customers',       2),
    ('erp', 'delivery_orders', 'brz', 'delivery_orders', 3);

SELECT * FROM dbo.pipeline_control;