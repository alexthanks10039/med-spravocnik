-- CreateTable
CREATE TABLE "DataRecordVersion" (
    "id" TEXT NOT NULL,
    "recordId" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "payload" JSONB NOT NULL,
    "checksum" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdBy" TEXT,

    CONSTRAINT "DataRecordVersion_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "DataRecordVersion_recordId_version_key" ON "DataRecordVersion"("recordId", "version");
CREATE INDEX "DataRecordVersion_recordId_createdAt_idx" ON "DataRecordVersion"("recordId", "createdAt");

ALTER TABLE "DataRecordVersion" ADD CONSTRAINT "DataRecordVersion_recordId_fkey" FOREIGN KEY ("recordId") REFERENCES "DataRecord"("id") ON DELETE CASCADE ON UPDATE CASCADE;
