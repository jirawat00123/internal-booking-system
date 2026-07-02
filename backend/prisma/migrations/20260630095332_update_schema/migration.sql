/*
  Warnings:

  - Made the column `return_by` on table `vehicle_logs` required. This step will fail if there are existing NULL values in that column.

*/
-- DropForeignKey
ALTER TABLE "vehicle_logs" DROP CONSTRAINT "vehicle_logs_return_by_fkey";

-- AlterTable
ALTER TABLE "vehicle_logs" ALTER COLUMN "return_by" SET NOT NULL;

-- AddForeignKey
ALTER TABLE "vehicle_logs" ADD CONSTRAINT "vehicle_logs_return_by_fkey" FOREIGN KEY ("return_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
