/*
  Warnings:

  - You are about to drop the column `booking_date` on the `room_bookings` table. All the data in the column will be lost.
  - You are about to drop the column `end_time` on the `room_bookings` table. All the data in the column will be lost.
  - You are about to drop the column `start_time` on the `room_bookings` table. All the data in the column will be lost.
  - Added the required column `end_datetime` to the `room_bookings` table without a default value. This is not possible if the table is not empty.
  - Added the required column `start_datetime` to the `room_bookings` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "room_bookings" DROP COLUMN "booking_date",
DROP COLUMN "end_time",
DROP COLUMN "start_time",
ADD COLUMN     "end_datetime" TIMESTAMP(3) NOT NULL,
ADD COLUMN     "start_datetime" TIMESTAMP(3) NOT NULL;
