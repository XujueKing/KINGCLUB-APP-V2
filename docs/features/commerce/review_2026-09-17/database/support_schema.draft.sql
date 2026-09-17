-- REVIEW ONLY. Run nowhere until approved and validated.
-- Depends on core_schema.draft.sql; no existing tables altered.

CREATE TABLE kc_draft_product_unit (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  product_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  unit_code VARCHAR(16) COLLATE utf8mb4_bin NOT NULL,
  base_factor DECIMAL(20,6) NOT NULL,
  quantity_scale TINYINT UNSIGNED NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  UNIQUE KEY uq_product_unit (tenant_ref, store_ref, product_ref, unit_code),
  CHECK (base_factor > 0 AND quantity_scale <= 6),
  CONSTRAINT fk_product_unit_0 FOREIGN KEY (tenant_ref, store_ref, product_ref) REFERENCES kc_draft_product (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: product_unit';

CREATE TABLE kc_draft_recipe_version (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  product_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  recipe_version INT UNSIGNED NOT NULL,
  state VARCHAR(16) NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  UNIQUE KEY uq_recipe_version (tenant_ref, store_ref, product_ref, recipe_version),
  CHECK (state IN ('draft','active','retired')),
  CONSTRAINT fk_recipe_version_0 FOREIGN KEY (tenant_ref, store_ref, product_ref) REFERENCES kc_draft_product (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: recipe_version';

CREATE TABLE kc_draft_recipe_line (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  recipe_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  component_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  base_quantity DECIMAL(20,6) NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  UNIQUE KEY uq_recipe_component (tenant_ref, store_ref, recipe_ref, component_ref),
  CHECK (base_quantity > 0),
  CONSTRAINT fk_recipe_line_0 FOREIGN KEY (tenant_ref, store_ref, recipe_ref) REFERENCES kc_draft_recipe_version (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_recipe_line_1 FOREIGN KEY (tenant_ref, store_ref, component_ref) REFERENCES kc_draft_product (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: recipe_line';

CREATE TABLE kc_draft_goods_receipt (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  purchase_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  command_id VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  received_at DATETIME(3) NOT NULL,
  state VARCHAR(16) NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  UNIQUE KEY uq_receipt_command (tenant_ref, store_ref, command_id),
  CHECK (state IN ('draft','confirmed','reversed')),
  CONSTRAINT fk_goods_receipt_0 FOREIGN KEY (tenant_ref, store_ref, purchase_ref) REFERENCES kc_draft_purchase (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: goods_receipt';

CREATE TABLE kc_draft_goods_receipt_line (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  receipt_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  purchase_line_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  batch_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  location_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  received_base_quantity DECIMAL(20,6) NOT NULL,
  unit_cost_minor DECIMAL(20,6) NOT NULL,
  currency CHAR(3) NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  UNIQUE KEY uq_receipt_batch (tenant_ref, store_ref, batch_ref),
  CHECK (received_base_quantity > 0 AND unit_cost_minor >= 0),
  CONSTRAINT fk_goods_receipt_line_0 FOREIGN KEY (tenant_ref, store_ref, receipt_ref) REFERENCES kc_draft_goods_receipt (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_goods_receipt_line_1 FOREIGN KEY (tenant_ref, store_ref, purchase_line_ref) REFERENCES kc_draft_purchase_line (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_goods_receipt_line_2 FOREIGN KEY (tenant_ref, store_ref, batch_ref) REFERENCES kc_draft_stock_batch (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_goods_receipt_line_3 FOREIGN KEY (tenant_ref, store_ref, location_ref) REFERENCES kc_draft_location (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: goods_receipt_line';

CREATE TABLE kc_draft_inventory_guard (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  product_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  location_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  UNIQUE KEY uq_guard (tenant_ref, store_ref, product_ref, location_ref),
  CONSTRAINT fk_inventory_guard_0 FOREIGN KEY (tenant_ref, store_ref, product_ref) REFERENCES kc_draft_product (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_inventory_guard_1 FOREIGN KEY (tenant_ref, store_ref, location_ref) REFERENCES kc_draft_location (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: inventory_guard';

CREATE TABLE kc_draft_business_command (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  action_name VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  command_id VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  request_hash BINARY(32) NOT NULL,
  outcome VARCHAR(16) NOT NULL,
  result_snapshot JSON NULL,
  error_snapshot JSON NULL,
  object_ref VARCHAR(64) COLLATE utf8mb4_bin NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  UNIQUE KEY uq_actor_command (tenant_ref, actor_ref, action_name, command_id),
  CHECK (outcome IN ('processing','succeeded','rejected'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: business_command';

CREATE TABLE kc_draft_audit_event (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  command_ref VARCHAR(64) COLLATE utf8mb4_bin NULL,
  action_name VARCHAR(64) NOT NULL,
  object_type VARCHAR(32) NOT NULL,
  object_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  event_at DATETIME(3) NOT NULL,
  reason VARCHAR(500) NULL,
  change_summary JSON NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  KEY ix_audit_object (tenant_ref, store_ref, object_type, object_ref, event_at),
  CONSTRAINT fk_audit_event_0 FOREIGN KEY (tenant_ref, store_ref, command_ref) REFERENCES kc_draft_business_command (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: audit_event';

CREATE TABLE kc_draft_outbox_event (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  source_event_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  event_type VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  payload JSON NOT NULL,
  state VARCHAR(16) NOT NULL,
  attempt_count INT UNSIGNED NOT NULL DEFAULT 0,
  next_attempt_at DATETIME(3) NOT NULL,
  lease_owner VARCHAR(64) COLLATE utf8mb4_bin NULL,
  lease_until DATETIME(3) NULL,
  last_error_code VARCHAR(64) NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  UNIQUE KEY uq_outbox_source (tenant_ref, store_ref, source_event_ref, event_type),
  KEY ix_outbox_ready (state, next_attempt_at),
  CHECK (state IN ('pending','leased','done','attention'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: outbox_event';

CREATE TABLE kc_draft_storage_holding_link (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  legacy_item_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  product_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  source_order_line_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  owner_member_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  source_kind VARCHAR(24) NOT NULL,
  original_deposited_at DATETIME(3) NOT NULL,
  expires_at DATETIME(3) NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  UNIQUE KEY uq_storage_link (legacy_item_ref),
  CHECK (source_kind IN ('direct_item','direct_package')),
  CHECK (expires_at > original_deposited_at),
  CONSTRAINT fk_storage_holding_link_0 FOREIGN KEY (tenant_ref, store_ref, product_ref) REFERENCES kc_draft_product (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_storage_holding_link_1 FOREIGN KEY (tenant_ref, store_ref, source_order_line_ref) REFERENCES kc_draft_sales_line (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: storage_holding_link';
