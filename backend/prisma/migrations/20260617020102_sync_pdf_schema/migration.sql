/*
  Warnings:

  - You are about to drop the column `booking_id` on the `attachments` table. All the data in the column will be lost.
  - You are about to drop the column `url` on the `attachments` table. All the data in the column will be lost.
  - You are about to drop the column `user_id` on the `room_bookings` table. All the data in the column will be lost.
  - You are about to drop the column `createdAt` on the `rooms` table. All the data in the column will be lost.
  - You are about to drop the column `description` on the `rooms` table. All the data in the column will be lost.
  - You are about to drop the column `isAvailable` on the `rooms` table. All the data in the column will be lost.
  - You are about to drop the column `name` on the `rooms` table. All the data in the column will be lost.
  - You are about to drop the column `department` on the `users` table. All the data in the column will be lost.
  - You are about to drop the column `division` on the `users` table. All the data in the column will be lost.
  - You are about to drop the column `email` on the `users` table. All the data in the column will be lost.
  - You are about to drop the column `employeeId` on the `users` table. All the data in the column will be lost.
  - You are about to drop the column `firstName` on the `users` table. All the data in the column will be lost.
  - You are about to drop the column `lastName` on the `users` table. All the data in the column will be lost.
  - You are about to drop the column `password` on the `users` table. All the data in the column will be lost.
  - You are about to drop the column `position` on the `users` table. All the data in the column will be lost.
  - You are about to drop the column `roleId` on the `users` table. All the data in the column will be lost.
  - You are about to drop the column `end_mileage` on the `vehicle_bookings` table. All the data in the column will be lost.
  - You are about to drop the column `end_time` on the `vehicle_bookings` table. All the data in the column will be lost.
  - You are about to drop the column `start_mileage` on the `vehicle_bookings` table. All the data in the column will be lost.
  - You are about to drop the column `start_time` on the `vehicle_bookings` table. All the data in the column will be lost.
  - You are about to drop the column `user_id` on the `vehicle_bookings` table. All the data in the column will be lost.
  - You are about to drop the column `action` on the `vehicle_logs` table. All the data in the column will be lost.
  - You are about to drop the column `booking_id` on the `vehicle_logs` table. All the data in the column will be lost.
  - You are about to drop the column `createdAt` on the `vehicles` table. All the data in the column will be lost.
  - You are about to drop the column `name` on the `vehicles` table. All the data in the column will be lost.
  - The `status` column on the `vehicles` table would be dropped and recreated. This will lead to data loss if there is data in the column.
  - You are about to drop the `pin_access` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `roles` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `room_logs` table. If the table is not empty, all the data it contains will be lost.
  - Added the required column `file_name` to the `attachments` table without a default value. This is not possible if the table is not empty.
  - Added the required column `file_path` to the `attachments` table without a default value. This is not possible if the table is not empty.
  - Added the required column `file_type` to the `attachments` table without a default value. This is not possible if the table is not empty.
  - Added the required column `uploaded_by` to the `attachments` table without a default value. This is not possible if the table is not empty.
  - Added the required column `vehicle_booking_id` to the `attachments` table without a default value. This is not possible if the table is not empty.
  - Added the required column `booking_date` to the `room_bookings` table without a default value. This is not possible if the table is not empty.
  - Added the required column `purpose` to the `room_bookings` table without a default value. This is not possible if the table is not empty.
  - Added the required column `location` to the `rooms` table without a default value. This is not possible if the table is not empty.
  - Added the required column `room_name` to the `rooms` table without a default value. This is not possible if the table is not empty.
  - Made the column `capacity` on table `rooms` required. This step will fail if there are existing NULL values in that column.
  - Added the required column `employee_id` to the `users` table without a default value. This is not possible if the table is not empty.
  - Added the required column `destination` to the `vehicle_bookings` table without a default value. This is not possible if the table is not empty.
  - Added the required column `driver_employee` to the `vehicle_bookings` table without a default value. This is not possible if the table is not empty.
  - Added the required column `end_datetime` to the `vehicle_bookings` table without a default value. This is not possible if the table is not empty.
  - Added the required column `purpose` to the `vehicle_bookings` table without a default value. This is not possible if the table is not empty.
  - Added the required column `start_datetime` to the `vehicle_bookings` table without a default value. This is not possible if the table is not empty.
  - Added the required column `updated_at` to the `vehicle_bookings` table without a default value. This is not possible if the table is not empty.
  - Added the required column `checkout_by` to the `vehicle_logs` table without a default value. This is not possible if the table is not empty.
  - Added the required column `checkout_fuel_level` to the `vehicle_logs` table without a default value. This is not possible if the table is not empty.
  - Added the required column `checkout_mileage` to the `vehicle_logs` table without a default value. This is not possible if the table is not empty.
  - Added the required column `checkout_time` to the `vehicle_logs` table without a default value. This is not possible if the table is not empty.
  - Added the required column `updated_at` to the `vehicle_logs` table without a default value. This is not possible if the table is not empty.
  - Added the required column `vehicle_booking_id` to the `vehicle_logs` table without a default value. This is not possible if the table is not empty.
  - Added the required column `brand` to the `vehicles` table without a default value. This is not possible if the table is not empty.
  - Added the required column `color` to the `vehicles` table without a default value. This is not possible if the table is not empty.
  - Added the required column `model` to the `vehicles` table without a default value. This is not possible if the table is not empty.
  - Added the required column `province` to the `vehicles` table without a default value. This is not possible if the table is not empty.
  - Added the required column `type` to the `vehicles` table without a default value. This is not possible if the table is not empty.
  - Added the required column `updated_at` to the `vehicles` table without a default value. This is not possible if the table is not empty.

*/
-- CreateEnum
CREATE TYPE "Role" AS ENUM ('ADMIN', 'USER');

-- CreateEnum
CREATE TYPE "RoomStatus" AS ENUM ('AVAILABLE', 'MAINTENANCE', 'INACTIVE');

-- CreateEnum
CREATE TYPE "VehicleStatus" AS ENUM ('AVAILABLE', 'IN USE', 'MAINTENANCE', 'INACTIVE');

-- DropForeignKey
ALTER TABLE "attachments" DROP CONSTRAINT "attachments_booking_id_fkey";

-- DropForeignKey
ALTER TABLE "pin_access" DROP CONSTRAINT "pin_access_role_id_fkey";

-- DropForeignKey
ALTER TABLE "room_bookings" DROP CONSTRAINT "room_bookings_user_id_fkey";

-- DropForeignKey
ALTER TABLE "room_logs" DROP CONSTRAINT "room_logs_booking_id_fkey";

-- DropForeignKey
ALTER TABLE "users" DROP CONSTRAINT "users_roleId_fkey";

-- DropForeignKey
ALTER TABLE "vehicle_bookings" DROP CONSTRAINT "vehicle_bookings_user_id_fkey";

-- DropForeignKey
ALTER TABLE "vehicle_logs" DROP CONSTRAINT "vehicle_logs_booking_id_fkey";

-- DropIndex
DROP INDEX "users_email_key";

-- DropIndex
DROP INDEX "users_employeeId_key";

-- AlterTable
ALTER TABLE "attachments" DROP COLUMN "booking_id",
DROP COLUMN "url",
ADD COLUMN     "file_name" TEXT NOT NULL,
ADD COLUMN     "file_path" TEXT NOT NULL,
ADD COLUMN     "file_type" TEXT NOT NULL,
ADD COLUMN     "uploaded_by" TEXT NOT NULL,
ADD COLUMN     "vehicle_booking_id" INTEGER NOT NULL;

-- AlterTable
ALTER TABLE "room_bookings" DROP COLUMN "user_id",
ADD COLUMN     "booking_date" TIMESTAMP(3) NOT NULL,
ADD COLUMN     "purpose" TEXT NOT NULL,
ALTER COLUMN "status" DROP DEFAULT;

-- AlterTable
ALTER TABLE "rooms" DROP COLUMN "createdAt",
DROP COLUMN "description",
DROP COLUMN "isAvailable",
DROP COLUMN "name",
ADD COLUMN     "location" TEXT NOT NULL,
ADD COLUMN     "room_name" TEXT NOT NULL,
ADD COLUMN     "status" "RoomStatus" NOT NULL DEFAULT 'AVAILABLE',
ALTER COLUMN "capacity" SET NOT NULL;

-- AlterTable
ALTER TABLE "users" DROP COLUMN "department",
DROP COLUMN "division",
DROP COLUMN "email",
DROP COLUMN "employeeId",
DROP COLUMN "firstName",
DROP COLUMN "lastName",
DROP COLUMN "password",
DROP COLUMN "position",
DROP COLUMN "roleId",
ADD COLUMN     "active" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "employee_id" INTEGER NOT NULL,
ADD COLUMN     "roles" "Role" NOT NULL DEFAULT 'USER';

-- AlterTable
ALTER TABLE "vehicle_bookings" DROP COLUMN "end_mileage",
DROP COLUMN "end_time",
DROP COLUMN "start_mileage",
DROP COLUMN "start_time",
DROP COLUMN "user_id",
ADD COLUMN     "destination" TEXT NOT NULL,
ADD COLUMN     "driver_employee" INTEGER NOT NULL,
ADD COLUMN     "end_datetime" TIMESTAMP(3) NOT NULL,
ADD COLUMN     "purpose" TEXT NOT NULL,
ADD COLUMN     "start_datetime" TIMESTAMP(3) NOT NULL,
ADD COLUMN     "updated_at" TIMESTAMP(3) NOT NULL,
ALTER COLUMN "status" DROP DEFAULT;

-- AlterTable
ALTER TABLE "vehicle_logs" DROP COLUMN "action",
DROP COLUMN "booking_id",
ADD COLUMN     "checkout_by" TEXT NOT NULL,
ADD COLUMN     "checkout_fuel_level" TEXT NOT NULL,
ADD COLUMN     "checkout_mileage" INTEGER NOT NULL,
ADD COLUMN     "checkout_time" TIMESTAMP(3) NOT NULL,
ADD COLUMN     "remark" TEXT,
ADD COLUMN     "return_by" TEXT,
ADD COLUMN     "return_fuel_level" TEXT,
ADD COLUMN     "return_mileage" INTEGER,
ADD COLUMN     "updated_at" TIMESTAMP(3) NOT NULL,
ADD COLUMN     "vehicle_booking_id" INTEGER NOT NULL;

-- AlterTable
ALTER TABLE "vehicles" DROP COLUMN "createdAt",
DROP COLUMN "name",
ADD COLUMN     "brand" TEXT NOT NULL,
ADD COLUMN     "color" TEXT NOT NULL,
ADD COLUMN     "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "model" TEXT NOT NULL,
ADD COLUMN     "province" TEXT NOT NULL,
ADD COLUMN     "type" TEXT NOT NULL,
ADD COLUMN     "updated_at" TIMESTAMP(3) NOT NULL,
ADD COLUMN     "upload_url" TEXT,
DROP COLUMN "status",
ADD COLUMN     "status" "VehicleStatus" NOT NULL DEFAULT 'AVAILABLE';

-- DropTable
DROP TABLE "pin_access";

-- DropTable
DROP TABLE "roles";

-- DropTable
DROP TABLE "room_logs";

-- CreateTable
CREATE TABLE "departments" (
    "id" SERIAL NOT NULL,
    "department_name" TEXT NOT NULL,

    CONSTRAINT "departments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "positions" (
    "id" SERIAL NOT NULL,
    "position_name" TEXT NOT NULL,
    "department_id" INTEGER NOT NULL,

    CONSTRAINT "positions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "employees" (
    "id" SERIAL NOT NULL,
    "employee_code" TEXT NOT NULL,
    "full_name" TEXT NOT NULL,
    "position_id" INTEGER NOT NULL,

    CONSTRAINT "employees_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" SERIAL NOT NULL,
    "action" TEXT NOT NULL,
    "module" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "employees_employee_code_key" ON "employees"("employee_code");

-- AddForeignKey
ALTER TABLE "positions" ADD CONSTRAINT "positions_department_id_fkey" FOREIGN KEY ("department_id") REFERENCES "departments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "employees" ADD CONSTRAINT "employees_position_id_fkey" FOREIGN KEY ("position_id") REFERENCES "positions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vehicle_bookings" ADD CONSTRAINT "vehicle_bookings_driver_employee_fkey" FOREIGN KEY ("driver_employee") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vehicle_logs" ADD CONSTRAINT "vehicle_logs_vehicle_booking_id_fkey" FOREIGN KEY ("vehicle_booking_id") REFERENCES "vehicle_bookings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attachments" ADD CONSTRAINT "attachments_vehicle_booking_id_fkey" FOREIGN KEY ("vehicle_booking_id") REFERENCES "vehicle_bookings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
