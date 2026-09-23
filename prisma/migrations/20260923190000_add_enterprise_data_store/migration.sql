CREATE TYPE "DataRecordStatus" AS ENUM ('ACTIVE', 'ARCHIVED');

CREATE TABLE "DataCollection" (
  "id" TEXT NOT NULL,
  "key" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "description" TEXT,
  "schema" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "DataCollection_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "DataRecord" (
  "id" TEXT NOT NULL,
  "collectionId" TEXT NOT NULL,
  "externalId" TEXT NOT NULL,
  "title" TEXT,
  "recordType" TEXT,
  "searchText" TEXT,
  "payload" JSONB NOT NULL,
  "status" "DataRecordStatus" NOT NULL DEFAULT 'ACTIVE',
  "version" INTEGER NOT NULL DEFAULT 1,
  "sourceFile" TEXT,
  "checksum" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "DataRecord_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "DataImport" (
  "id" TEXT NOT NULL,
  "collectionId" TEXT NOT NULL,
  "filename" TEXT,
  "format" TEXT NOT NULL,
  "status" TEXT NOT NULL,
  "total" INTEGER NOT NULL DEFAULT 0,
  "imported" INTEGER NOT NULL DEFAULT 0,
  "rejected" INTEGER NOT NULL DEFAULT 0,
  "errors" JSONB,
  "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "finishedAt" TIMESTAMP(3),
  CONSTRAINT "DataImport_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "AuditLog" (
  "id" TEXT NOT NULL,
  "userId" TEXT,
  "action" TEXT NOT NULL,
  "entity" TEXT NOT NULL,
  "entityId" TEXT,
  "metadata" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "AuditLog_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "DataCollection_key_key" ON "DataCollection"("key");
CREATE UNIQUE INDEX "DataRecord_collectionId_externalId_key" ON "DataRecord"("collectionId", "externalId");
CREATE INDEX "DataRecord_collectionId_status_updatedAt_idx" ON "DataRecord"("collectionId", "status", "updatedAt");
CREATE INDEX "DataRecord_collectionId_title_idx" ON "DataRecord"("collectionId", "title");
CREATE INDEX "DataRecord_collectionId_recordType_idx" ON "DataRecord"("collectionId", "recordType");
CREATE INDEX "DataImport_collectionId_startedAt_idx" ON "DataImport"("collectionId", "startedAt");
CREATE INDEX "AuditLog_userId_createdAt_idx" ON "AuditLog"("userId", "createdAt");
CREATE INDEX "AuditLog_entity_entityId_createdAt_idx" ON "AuditLog"("entity", "entityId", "createdAt");

ALTER TABLE "DataRecord" ADD CONSTRAINT "DataRecord_collectionId_fkey" FOREIGN KEY ("collectionId") REFERENCES "DataCollection"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "DataImport" ADD CONSTRAINT "DataImport_collectionId_fkey" FOREIGN KEY ("collectionId") REFERENCES "DataCollection"("id") ON DELETE CASCADE ON UPDATE CASCADE;
