CREATE TYPE "customer_segment" AS ENUM (
  'Retail',
  'Wholesale',
  'VIP'
);

CREATE TYPE "customer_status" AS ENUM (
  'active',
  'inactive',
  'suspended'
);

CREATE TYPE "order_status" AS ENUM (
  'pending',
  'confirmed',
  'shipped',
  'completed',
  'cancelled'
);

CREATE TYPE "payment_status" AS ENUM (
  'pending',
  'success',
  'failed',
  'refunded'
);

CREATE TABLE "customers" (
  "customer_id" varchar PRIMARY KEY,
  "name" varchar NOT NULL,
  "email" varchar(255) UNIQUE NOT NULL,
  "phone" varchar(20),
  "segment" customer_segment,
  "city" varchar,
  "status" customer_status DEFAULT 'active',
  "created_at" timestamptz DEFAULT (now()),
  "updated_at" timestamptz DEFAULT (now()),
  "source_system" varchar NOT NULL,
  "ingested_at" timestamptz DEFAULT (now())
);

CREATE TABLE "categories" (
  "category_id" varchar PRIMARY KEY,
  "name" varchar UNIQUE NOT NULL,
  "parent_category_id" varchar
);

CREATE TABLE "products" (
  "product_id" varchar PRIMARY KEY,
  "name" varchar NOT NULL,
  "category_id" varchar NOT NULL,
  "unit_price" numeric(14,2) NOT NULL,
  "cost_price" numeric(14,2) NOT NULL,
  "status" varchar NOT NULL DEFAULT 'active',
  "created_at" timestamptz DEFAULT (now()),
  "updated_at" timestamptz DEFAULT (now()),
  "source_system" varchar NOT NULL,
  "ingested_at" timestamptz DEFAULT (now())
);

CREATE TABLE "orders" (
  "order_id" varchar PRIMARY KEY,
  "customer_id" varchar NOT NULL,
  "order_date" timestamptz NOT NULL DEFAULT (now()),
  "status" order_status NOT NULL DEFAULT 'pending',
  "channel" varchar NOT NULL,
  "created_at" timestamptz DEFAULT (now()),
  "updated_at" timestamptz DEFAULT (now()),
  "source_system" varchar NOT NULL,
  "ingested_at" timestamptz DEFAULT (now())
);

CREATE TABLE "order_items" (
  "order_item_id" varchar PRIMARY KEY,
  "order_id" varchar NOT NULL,
  "product_id" varchar NOT NULL,
  "quantity" integer NOT NULL,
  "unit_price" numeric(14,2) NOT NULL,
  "discount" numeric(14,2) NOT NULL DEFAULT 0
);

CREATE TABLE "payments" (
  "payment_id" varchar PRIMARY KEY,
  "order_id" varchar NOT NULL,
  "amount" numeric(14,2) NOT NULL,
  "payment_method" varchar NOT NULL,
  "status" payment_status NOT NULL DEFAULT 'pending',
  "payment_date" timestamptz NOT NULL DEFAULT (now()),
  "created_at" timestamptz DEFAULT (now()),
  "updated_at" timestamptz DEFAULT (now())
);

COMMENT ON COLUMN "customers"."customer_id" IS 'Format: CUS000001';

COMMENT ON COLUMN "customers"."updated_at" IS 'Incremental load key';

COMMENT ON COLUMN "products"."product_id" IS 'Format: PRD000001';

COMMENT ON COLUMN "products"."unit_price" IS 'unit_price >= 0';

COMMENT ON COLUMN "products"."cost_price" IS 'cost_price >= 0';

COMMENT ON COLUMN "orders"."order_id" IS 'Format: ORD000001';

COMMENT ON COLUMN "orders"."updated_at" IS 'Incremental load key';

COMMENT ON COLUMN "order_items"."quantity" IS 'quantity > 0';

COMMENT ON COLUMN "order_items"."unit_price" IS 'unit_price >= 0';

COMMENT ON COLUMN "order_items"."discount" IS '0 <= discount <= unit_price * quantity';

COMMENT ON COLUMN "payments"."amount" IS 'amount >= 0';

COMMENT ON COLUMN "payments"."payment_date" IS 'payment_date >= order_date';

ALTER TABLE "categories" ADD FOREIGN KEY ("parent_category_id") REFERENCES "categories" ("category_id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "products" ADD FOREIGN KEY ("category_id") REFERENCES "categories" ("category_id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "orders" ADD FOREIGN KEY ("customer_id") REFERENCES "customers" ("customer_id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "order_items" ADD FOREIGN KEY ("order_id") REFERENCES "orders" ("order_id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "order_items" ADD FOREIGN KEY ("product_id") REFERENCES "products" ("product_id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "payments" ADD FOREIGN KEY ("order_id") REFERENCES "orders" ("order_id") DEFERRABLE INITIALLY IMMEDIATE;
