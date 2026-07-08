/*
  Warnings:

  - Added the required column `vehicle_name` to the `vehicles` table without a default value. This is not possible if the table is not empty.

*/
-- DropForeignKey
ALTER TABLE "vehicle_logs" DROP CONSTRAINT "vehicle_logs_return_by_fkey";

-- AlterTable
ALTER TABLE "vehicle_logs" ALTER COLUMN "return_by" DROP NOT NULL;

-- AlterTable
ALTER TABLE "vehicles" ADD COLUMN     "vehicle_name" TEXT NOT NULL,
ALTER COLUMN "updated_at" SET DEFAULT CURRENT_TIMESTAMP;

-- CreateTable
CREATE TABLE "room_booking_histories" (
    "id" SERIAL NOT NULL,
    "room_booking_id" INTEGER NOT NULL,
    "changed_by_id" INTEGER NOT NULL,
    "action" TEXT NOT NULL,
    "status_snapshot" TEXT NOT NULL,
    "remark" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "room_booking_histories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vehicle_booking_histories" (
    "id" SERIAL NOT NULL,
    "vehicle_booking_id" INTEGER NOT NULL,
    "changed_by_id" INTEGER NOT NULL,
    "action" TEXT NOT NULL,
    "status_snapshot" TEXT NOT NULL,
    "remark" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vehicle_booking_histories_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "room_booking_histories_room_booking_id_idx" ON "room_booking_histories"("room_booking_id");

-- CreateIndex
CREATE INDEX "room_booking_histories_changed_by_id_idx" ON "room_booking_histories"("changed_by_id");

-- CreateIndex
CREATE INDEX "vehicle_booking_histories_vehicle_booking_id_idx" ON "vehicle_booking_histories"("vehicle_booking_id");

-- CreateIndex
CREATE INDEX "vehicle_booking_histories_changed_by_id_idx" ON "vehicle_booking_histories"("changed_by_id");

-- AddForeignKey
ALTER TABLE "vehicle_logs" ADD CONSTRAINT "vehicle_logs_return_by_fkey" FOREIGN KEY ("return_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_booking_histories" ADD CONSTRAINT "room_booking_histories_room_booking_id_fkey" FOREIGN KEY ("room_booking_id") REFERENCES "room_bookings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_booking_histories" ADD CONSTRAINT "room_booking_histories_changed_by_id_fkey" FOREIGN KEY ("changed_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vehicle_booking_histories" ADD CONSTRAINT "vehicle_booking_histories_vehicle_booking_id_fkey" FOREIGN KEY ("vehicle_booking_id") REFERENCES "vehicle_bookings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vehicle_booking_histories" ADD CONSTRAINT "vehicle_booking_histories_changed_by_id_fkey" FOREIGN KEY ("changed_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
