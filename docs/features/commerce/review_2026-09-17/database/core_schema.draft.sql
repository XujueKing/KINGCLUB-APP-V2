-- REVIEW DRAFT ONLY. MySQL 8 candidate DDL. Do not run as a migration.
-- REUSE REVIEW REQUIRED: see REUSE_REVIEW.md and EXISTING_TABLE_INVENTORY.md.
-- Candidate relations only, NOT a list of mandatory new tables. Naming/catalog not production-ready.
-- No CREATE DATABASE, DROP, ALTER, INSERT, or imported data.
-- kc_draft_* names are placeholders; existing identity/wallet/store integration is unresolved.

CREATE TABLE kc_draft_supplier (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  name VARCHAR(128) NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: supplier';

CREATE TABLE kc_draft_product (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  name VARCHAR(128) NOT NULL,
  names JSON NOT NULL,
  kind VARCHAR(24) NOT NULL,
  base_unit VARCHAR(16) NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  CHECK (kind IN ('stock','bundle','consumable'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: product';

CREATE TABLE kc_draft_purchase (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  supplier_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  state VARCHAR(24) NOT NULL,
  currency CHAR(3) NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  CONSTRAINT fk_purchase_0 FOREIGN KEY (tenant_ref, store_ref, supplier_ref) REFERENCES kc_draft_supplier (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: purchase';

CREATE TABLE kc_draft_purchase_line (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  purchase_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  product_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ordered_quantity DECIMAL(20,6) NOT NULL,
  unit_cost_minor DECIMAL(20,6) NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  CHECK (ordered_quantity > 0 AND unit_cost_minor >= 0),
  CONSTRAINT fk_purchase_line_0 FOREIGN KEY (tenant_ref, store_ref, purchase_ref) REFERENCES kc_draft_purchase (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_purchase_line_1 FOREIGN KEY (tenant_ref, store_ref, product_ref) REFERENCES kc_draft_product (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: purchase_line';

CREATE TABLE kc_draft_location (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  name VARCHAR(128) NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: location';

CREATE TABLE kc_draft_stock_batch (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  purchase_line_ref VARCHAR(64) COLLATE utf8mb4_bin NULL,
  product_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  received_quantity DECIMAL(20,6) NOT NULL,
  unit_cost_minor DECIMAL(20,6) NOT NULL,
  currency CHAR(3) NOT NULL,
  received_at DATETIME(3) NOT NULL,
  expires_at DATETIME(3) NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  CHECK (received_quantity > 0 AND unit_cost_minor >= 0),
  CONSTRAINT fk_stock_batch_0 FOREIGN KEY (tenant_ref, store_ref, purchase_line_ref) REFERENCES kc_draft_purchase_line (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_stock_batch_1 FOREIGN KEY (tenant_ref, store_ref, product_ref) REFERENCES kc_draft_product (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: stock_batch';

CREATE TABLE kc_draft_stock_balance (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  batch_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  location_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  on_hand DECIMAL(20,6) NOT NULL DEFAULT 0,
  reserved DECIMAL(20,6) NOT NULL DEFAULT 0,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  UNIQUE KEY uq_balance (tenant_ref, store_ref, batch_ref, location_ref),
  CHECK (on_hand >= 0 AND reserved >= 0 AND reserved <= on_hand),
  CONSTRAINT fk_stock_balance_0 FOREIGN KEY (tenant_ref, store_ref, batch_ref) REFERENCES kc_draft_stock_batch (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_stock_balance_1 FOREIGN KEY (tenant_ref, store_ref, location_ref) REFERENCES kc_draft_location (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: stock_balance';

CREATE TABLE kc_draft_activity (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  name VARCHAR(128) NOT NULL,
  starts_at DATETIME(3) NOT NULL,
  state VARCHAR(24) NOT NULL,
  policy_snapshot JSON NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  CHECK (state IN ('draft','open','stopped','ended'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: activity';

CREATE TABLE kc_draft_table_config (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  name VARCHAR(64) NOT NULL,
  min_seats INT UNSIGNED NOT NULL,
  max_seats INT UNSIGNED NOT NULL,
  gender_rule JSON NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  CHECK (min_seats > 0 AND min_seats <= max_seats)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: table_config';

CREATE TABLE kc_draft_table_session (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  table_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  activity_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  starts_at DATETIME(3) NOT NULL,
  ends_at DATETIME(3) NOT NULL,
  state VARCHAR(24) NOT NULL,
  config_snapshot JSON NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  CHECK (ends_at > starts_at),
  KEY ix_table_time (tenant_ref, store_ref, table_ref, starts_at, ends_at),
  CONSTRAINT fk_table_session_0 FOREIGN KEY (tenant_ref, store_ref, table_ref) REFERENCES kc_draft_table_config (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_table_session_1 FOREIGN KEY (tenant_ref, store_ref, activity_ref) REFERENCES kc_draft_activity (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: table_session';

CREATE TABLE kc_draft_registration (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  activity_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  member_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  entitlement_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  state VARCHAR(24) NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  CONSTRAINT fk_registration_0 FOREIGN KEY (tenant_ref, store_ref, activity_ref) REFERENCES kc_draft_activity (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: registration';

CREATE TABLE kc_draft_current_registration (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  registration_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  activity_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  member_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  UNIQUE KEY uq_current_member (tenant_ref, store_ref, activity_ref, member_ref),
  UNIQUE KEY uq_current_reg (tenant_ref, store_ref, registration_ref),
  CONSTRAINT fk_current_registration_0 FOREIGN KEY (tenant_ref, store_ref, registration_ref) REFERENCES kc_draft_registration (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_current_registration_1 FOREIGN KEY (tenant_ref, store_ref, activity_ref) REFERENCES kc_draft_activity (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: current_registration';

CREATE TABLE kc_draft_seat_assignment (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  registration_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  session_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  assigned_at DATETIME(3) NOT NULL,
  released_at DATETIME(3) NULL,
  seated_at DATETIME(3) NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  CONSTRAINT fk_seat_assignment_0 FOREIGN KEY (tenant_ref, store_ref, registration_ref) REFERENCES kc_draft_registration (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_seat_assignment_1 FOREIGN KEY (tenant_ref, store_ref, session_ref) REFERENCES kc_draft_table_session (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: seat_assignment';

CREATE TABLE kc_draft_current_seat (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  registration_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  assignment_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  UNIQUE KEY uq_current_seat (tenant_ref, store_ref, registration_ref),
  UNIQUE KEY uq_assignment (tenant_ref, store_ref, assignment_ref),
  CONSTRAINT fk_current_seat_0 FOREIGN KEY (tenant_ref, store_ref, registration_ref) REFERENCES kc_draft_registration (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_current_seat_1 FOREIGN KEY (tenant_ref, store_ref, assignment_ref) REFERENCES kc_draft_seat_assignment (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: current_seat';

CREATE TABLE kc_draft_sales_order (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  member_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  session_ref VARCHAR(64) COLLATE utf8mb4_bin NULL,
  kind VARCHAR(24) NOT NULL,
  payment_state VARCHAR(24) NOT NULL,
  fulfillment_state VARCHAR(24) NOT NULL,
  total_minor BIGINT NOT NULL,
  currency CHAR(3) NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  CHECK (total_minor >= 0),
  CONSTRAINT fk_sales_order_0 FOREIGN KEY (tenant_ref, store_ref, session_ref) REFERENCES kc_draft_table_session (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: sales_order';

CREATE TABLE kc_draft_sales_line (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  order_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  product_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  quantity DECIMAL(20,6) NOT NULL,
  line_total_minor BIGINT NOT NULL,
  offer_snapshot JSON NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  CHECK (quantity > 0 AND line_total_minor >= 0),
  CONSTRAINT fk_sales_line_0 FOREIGN KEY (tenant_ref, store_ref, order_ref) REFERENCES kc_draft_sales_order (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_sales_line_1 FOREIGN KEY (tenant_ref, store_ref, product_ref) REFERENCES kc_draft_product (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: sales_line';

CREATE TABLE kc_draft_aa_group (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  initiator_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  session_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  order_ref VARCHAR(64) COLLATE utf8mb4_bin NULL,
  share_count INT UNSIGNED NOT NULL,
  total_minor BIGINT NOT NULL,
  currency CHAR(3) NOT NULL,
  expires_at DATETIME(3) NOT NULL,
  group_state VARCHAR(24) NOT NULL,
  refund_state VARCHAR(24) NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  CHECK (share_count >= 2 AND total_minor > 0),
  CHECK (group_state IN ('collecting','formed','closed')),
  CHECK (refund_state IN ('not_required','pending','processing','completed','attention_required')),
  KEY ix_aa_expiry (group_state, expires_at),
  UNIQUE KEY uq_aa_order (tenant_ref, store_ref, order_ref),
  CONSTRAINT fk_aa_group_0 FOREIGN KEY (tenant_ref, store_ref, session_ref) REFERENCES kc_draft_table_session (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_aa_group_1 FOREIGN KEY (tenant_ref, store_ref, order_ref) REFERENCES kc_draft_sales_order (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: aa_group';

CREATE TABLE kc_draft_aa_share (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  group_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  share_index INT UNSIGNED NOT NULL,
  amount_minor BIGINT NOT NULL,
  payer_ref VARCHAR(64) COLLATE utf8mb4_bin NULL,
  state VARCHAR(24) NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  UNIQUE KEY uq_share (tenant_ref, store_ref, group_ref, share_index),
  CHECK (amount_minor > 0),
  CONSTRAINT fk_aa_share_0 FOREIGN KEY (tenant_ref, store_ref, group_ref) REFERENCES kc_draft_aa_group (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: aa_share';

CREATE TABLE kc_draft_payment_fact (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  order_ref VARCHAR(64) COLLATE utf8mb4_bin NULL,
  share_ref VARCHAR(64) COLLATE utf8mb4_bin NULL,
  payer_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  channel_ref VARCHAR(32) COLLATE utf8mb4_bin NOT NULL,
  merchant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  external_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  amount_minor BIGINT NOT NULL,
  refunded_minor BIGINT NOT NULL DEFAULT 0,
  currency CHAR(3) NOT NULL,
  confirmed_at DATETIME(3) NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  UNIQUE KEY uq_external_payment (channel_ref, merchant_ref, external_ref),
  CHECK (amount_minor > 0 AND refunded_minor >= 0 AND refunded_minor <= amount_minor),
  CHECK ((order_ref IS NULL) <> (share_ref IS NULL)),
  CONSTRAINT fk_payment_fact_0 FOREIGN KEY (tenant_ref, store_ref, order_ref) REFERENCES kc_draft_sales_order (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_payment_fact_1 FOREIGN KEY (tenant_ref, store_ref, share_ref) REFERENCES kc_draft_aa_share (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: payment_fact';

CREATE TABLE kc_draft_refund_intent (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  payment_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  cause_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  amount_minor BIGINT NOT NULL,
  destination VARCHAR(24) NOT NULL,
  state VARCHAR(24) NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  UNIQUE KEY uq_refund_cause (tenant_ref, store_ref, payment_ref, cause_ref),
  CHECK (amount_minor > 0),
  CONSTRAINT fk_refund_intent_0 FOREIGN KEY (tenant_ref, store_ref, payment_ref) REFERENCES kc_draft_payment_fact (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: refund_intent';

CREATE TABLE kc_draft_stock_reservation (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  source_type VARCHAR(24) NOT NULL,
  source_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  state VARCHAR(24) NOT NULL,
  expires_at DATETIME(3) NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  UNIQUE KEY uq_reservation_source (tenant_ref, store_ref, source_type, source_ref),
  CHECK (state IN ('active','consumed','released'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: stock_reservation';

CREATE TABLE kc_draft_reservation_line (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  reservation_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  balance_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  quantity DECIMAL(20,6) NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  UNIQUE KEY uq_reserved_balance (tenant_ref, store_ref, reservation_ref, balance_ref),
  CHECK (quantity > 0),
  CONSTRAINT fk_reservation_line_0 FOREIGN KEY (tenant_ref, store_ref, reservation_ref) REFERENCES kc_draft_stock_reservation (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_reservation_line_1 FOREIGN KEY (tenant_ref, store_ref, balance_ref) REFERENCES kc_draft_stock_balance (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: reservation_line';

CREATE TABLE kc_draft_inventory_issue (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  source_type VARCHAR(24) NOT NULL,
  source_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  purpose VARCHAR(24) NOT NULL,
  confirmed_at DATETIME(3) NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  UNIQUE KEY uq_issue_source (tenant_ref, store_ref, source_type, source_ref, purpose)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: inventory_issue';

CREATE TABLE kc_draft_inventory_movement (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  balance_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  issue_ref VARCHAR(64) COLLATE utf8mb4_bin NULL,
  source_type VARCHAR(24) NOT NULL,
  source_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  quantity_delta DECIMAL(20,6) NOT NULL,
  cost_minor BIGINT NOT NULL,
  currency CHAR(3) NOT NULL,
  reversal_of VARCHAR(64) COLLATE utf8mb4_bin NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  CHECK (quantity_delta <> 0),
  KEY ix_movement_balance (tenant_ref, store_ref, balance_ref, created_at),
  CONSTRAINT fk_inventory_movement_0 FOREIGN KEY (tenant_ref, store_ref, balance_ref) REFERENCES kc_draft_stock_balance (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_inventory_movement_1 FOREIGN KEY (tenant_ref, store_ref, issue_ref) REFERENCES kc_draft_inventory_issue (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_inventory_movement_2 FOREIGN KEY (tenant_ref, store_ref, reversal_of) REFERENCES kc_draft_inventory_movement (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: inventory_movement';

CREATE TABLE kc_draft_shared_package (
  tenant_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  store_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  session_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  issue_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  recipe_snapshot JSON NOT NULL,
  delivery_state VARCHAR(24) NOT NULL,
  actor_ref VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tenant_ref, store_ref, ref),
  CHECK (version > 0),
  UNIQUE KEY uq_session_package (tenant_ref, store_ref, session_ref),
  UNIQUE KEY uq_package_issue (tenant_ref, store_ref, issue_ref),
  CONSTRAINT fk_shared_package_0 FOREIGN KEY (tenant_ref, store_ref, session_ref) REFERENCES kc_draft_table_session (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_shared_package_1 FOREIGN KEY (tenant_ref, store_ref, issue_ref) REFERENCES kc_draft_inventory_issue (tenant_ref, store_ref, ref) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Commerce review draft: shared_package';
