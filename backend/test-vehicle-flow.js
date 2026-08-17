/**
 * ====================================================================
 * 🧪 AUTOMATED INTEGRATION TEST: VEHICLE BOOKING WORKFLOW (STEP 3)
 * ====================================================================
 * Schema-Aligned Integration Test Suite for Prisma & PostgreSQL
 */

const { PrismaClient } = require('@prisma/client');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
require('dotenv').config();

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'SuperSecretKey2026_ForCorporateApp!!';
const PORT = process.env.PORT || 3001;
const BASE_URL = `http://127.0.0.1:${PORT}/api/vehicle-bookings`;

// Variable trackers for cleanup
let testUser, testAdmin, testVehicle;
let createdBookingId = null;

// Helper: Custom fetch for Node.js
async function apiRequest(url, method, token, body = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const options = { method, headers };
  if (body) options.body = JSON.stringify(body);

  const res = await fetch(url, options);
  const data = await res.json().catch(() => ({}));
  return { status: res.status, body: data };
}

// Dynamic PostgreSQL Sequence Fixer for all public tables
async function fixAllSequences() {
  try {
    await prisma.$executeRawUnsafe(`
      DO $$ 
      DECLARE 
          r RECORD;
          seq TEXT;
      BEGIN 
          FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP 
              BEGIN
                  seq := pg_get_serial_sequence(quote_ident(r.tablename), 'id');
                  IF seq IS NOT NULL THEN
                      EXECUTE 'SELECT setval(''' || seq || ''', COALESCE((SELECT MAX(id) FROM ' || quote_ident(r.tablename) || '), 1) + 1, false);';
                  END IF;
              EXCEPTION WHEN OTHERS THEN
                  -- Ignore tables without serial id
              END;
          END LOOP; 
      END $$;
    `);
  } catch (err) {
    // Non-Postgres fallback safely ignored
  }
}

// Helper: Generate Auth Token and Update Session in DB
async function generateTestAuthToken(userId, role, employeeCode) {
  const newSessionId = crypto.randomUUID();
  await prisma.user.update({
    where: { id: userId },
    data: { currentSessionId: newSessionId }
  });

  return jwt.sign(
    { userId, role, employeeCode, sessionId: newSessionId },
    JWT_SECRET,
    { expiresIn: '1h' }
  );
}

async function runTestFlow() {
  console.log('\n======================================================');
  console.log('🚀 STARTING INTEGRATION TEST: VEHICLE WORKFLOW');
  console.log('======================================================\n');

  try {
    // --------------------------------------------------------
    // SETUP: เตรียมข้อมูลทดสอบเฉพาะกิจใน DB (Mock Data)
    // --------------------------------------------------------
    console.log('📦 [SETUP] Resetting PostgreSQL Sequences & Preparing Test Data...');

    // 0. ซิงค์ Auto-Increment Sequences ของทุกตารางใน DB ให้ตรงกับ MAX(id)
    await fixAllSequences();

    // 1. หา หรือ สร้าง Department และ Position สำหรับผูกกับ Employee
    let testDept = await prisma.department.findFirst();
    if (!testDept) {
      testDept = await prisma.department.create({
        data: { departmentName: 'Test Department' }
      });
    }

    let testPos = await prisma.position.findFirst();
    if (!testPos) {
      testPos = await prisma.position.create({
        data: {
          positionName: 'Test Position',
          departmentId: testDept.id
        }
      });
    }

    // 2. หา หรือ สร้าง Role ADMIN และ USER
    let adminRole = await prisma.role.findFirst({ where: { name: 'ADMIN' } });
    if (!adminRole) {
      adminRole = await prisma.role.create({ data: { name: 'ADMIN' } });
    }

    let userRole = await prisma.role.findFirst({ where: { name: 'USER' } });
    if (!userRole) {
      userRole = await prisma.role.create({ data: { name: 'USER' } });
    }

    const timestamp = Date.now();
    const testPlate = `TST-${timestamp.toString().slice(-4)}`;

    // 3. สร้าง Test Employees
    const empUser = await prisma.employee.create({
      data: { 
        employeeCode: `EMP_USR_${timestamp}`, 
        fullName: 'Test User Integration',
        departmentId: testDept.id,
        positionId: testPos.id
      }
    });
    const empAdmin = await prisma.employee.create({
      data: { 
        employeeCode: `EMP_ADM_${timestamp}`, 
        fullName: 'Test Admin Integration',
        departmentId: testDept.id,
        positionId: testPos.id
      }
    });

    // 4. สร้าง Test Users
    testUser = await prisma.user.create({
      data: {
        employeeId: empUser.id,
        roleId: userRole.id,
        active: true,
        isDeleted: false,
        pinResetRequired: false
      }
    });

    testAdmin = await prisma.user.create({
      data: {
        employeeId: empAdmin.id,
        roleId: adminRole.id,
        active: true,
        isDeleted: false,
        pinResetRequired: false
      }
    });

    // 5. สร้าง Test Vehicle (ตรงตาม Required Fields ของ Schema)
    testVehicle = await prisma.vehicle.create({
      data: {
        vehicleName: `Test Vehicle ${testPlate}`,
        plateNumber: testPlate,
        brand: 'Toyota',
        model: 'Camry Test',
        status: 'AVAILABLE',
        isDeleted: false
      }
    });

    const userToken = await generateTestAuthToken(testUser.id, 'USER', empUser.employeeCode);
    const adminToken = await generateTestAuthToken(testAdmin.id, 'ADMIN', empAdmin.employeeCode);

    console.log('✅ [SETUP SUCCESS] Mock entities created successfully.\n');

    // --------------------------------------------------------
    // TEST 1: CREATE BOOKING -> PENDING & Vehicle AVAILABLE
    // --------------------------------------------------------
    console.log('🧪 [TEST 1] Testing CREATE BOOKING (Expect: HTTP 201, Booking: PENDING, Vehicle: AVAILABLE)');
    
    const startDatetime = new Date(Date.now() + 86400000).toISOString();
    const endDatetime = new Date(Date.now() + 86400000 + 7200000).toISOString();

    const res1 = await apiRequest(BASE_URL, 'POST', userToken, {
      vehicleId: testVehicle.id,
      startDatetime,
      endDatetime,
      destination: 'ชลบุรี',
      purpose: 'ทดสอบระบบ',
      passengers: 2
    });

    console.log(`   -> HTTP Status: ${res1.status}`);
    if (res1.status !== 201) throw new Error(`Test 1 Failed! HTTP Status is ${res1.status}: ${JSON.stringify(res1.body)}`);

    createdBookingId = res1.body.data.id;
    
    // DB Verification
    const dbBooking1 = await prisma.vehicleBooking.findUnique({ where: { id: createdBookingId } });
    const dbVehicle1 = await prisma.vehicle.findUnique({ where: { id: testVehicle.id } });

    console.log(`   -> DB Booking Status: "${dbBooking1.status}" (Expect: PENDING)`);
    console.log(`   -> DB Vehicle Status: "${dbVehicle1.status}" (Expect: AVAILABLE)`);

    if (dbBooking1.status !== 'PENDING' || dbVehicle1.status !== 'AVAILABLE') {
      throw new Error('Test 1 Failed! DB State mismatch.');
    }
    console.log('✅ [TEST 1 PASSED]\n');

    // --------------------------------------------------------
    // TEST 2: APPROVE BOOKING -> APPROVED & Vehicle AVAILABLE
    // --------------------------------------------------------
    console.log('🧪 [TEST 2] Testing APPROVE BOOKING (Expect: HTTP 200, Booking: APPROVED, Vehicle: AVAILABLE)');

    const res2 = await apiRequest(`${BASE_URL}/${createdBookingId}/approve`, 'POST', adminToken);
    console.log(`   -> HTTP Status: ${res2.status}`);
    if (res2.status !== 200) throw new Error(`Test 2 Failed! HTTP Status is ${res2.status}: ${JSON.stringify(res2.body)}`);

    const dbBooking2 = await prisma.vehicleBooking.findUnique({ where: { id: createdBookingId } });
    const dbVehicle2 = await prisma.vehicle.findUnique({ where: { id: testVehicle.id } });

    console.log(`   -> DB Booking Status: "${dbBooking2.status}" (Expect: APPROVED)`);
    console.log(`   -> DB Vehicle Status: "${dbVehicle2.status}" (Expect: AVAILABLE - NOT RESERVED)`);

    if (dbBooking2.status !== 'APPROVED' || dbVehicle2.status !== 'AVAILABLE') {
      throw new Error('Test 2 Failed! DB State mismatch. (Vehicle status should remain AVAILABLE)');
    }
    console.log('✅ [TEST 2 PASSED]\n');

    // --------------------------------------------------------
    // TEST 3: COLLISION CHECK -> 409 CONFLICT
    // --------------------------------------------------------
    console.log('🧪 [TEST 3] Testing TIME COLLISION CHECK (Expect: HTTP 409 CONFLICT)');

    const overlapStart = new Date(Date.now() + 86400000 + 3600000).toISOString();
    const overlapEnd = new Date(Date.now() + 86400000 + 10800000).toISOString();

    const res3 = await apiRequest(BASE_URL, 'POST', userToken, {
      vehicleId: testVehicle.id,
      startDatetime: overlapStart,
      endDatetime: overlapEnd,
      destination: 'ระยอง',
      purpose: 'ทดสอบเวลาซ้อน',
      passengers: 1
    });

    console.log(`   -> HTTP Status: ${res3.status} (Expect: 409)`);
    if (res3.status !== 409) throw new Error(`Test 3 Failed! Expected HTTP 409 Conflict, but got ${res3.status}`);
    console.log('✅ [TEST 3 PASSED]\n');

    // --------------------------------------------------------
    // TEST 4: RELEASE VEHICLE -> IN_USE & Vehicle IN_USE
    // --------------------------------------------------------
    console.log('🧪 [TEST 4] Testing RELEASE VEHICLE (Expect: HTTP 200, Booking: IN_USE, Vehicle: IN_USE)');

    const res4 = await apiRequest(`${BASE_URL}/${createdBookingId}/release`, 'PUT', userToken, { status: 'IN_USE' });
    console.log(`   -> HTTP Status: ${res4.status}`);
    if (res4.status !== 200) throw new Error(`Test 4 Failed! HTTP Status is ${res4.status}: ${JSON.stringify(res4.body)}`);

    const dbBooking4 = await prisma.vehicleBooking.findUnique({ where: { id: createdBookingId } });
    const dbVehicle4 = await prisma.vehicle.findUnique({ where: { id: testVehicle.id } });

    console.log(`   -> DB Booking Status: "${dbBooking4.status}" (Expect: IN_USE)`);
    console.log(`   -> DB Vehicle Status: "${dbVehicle4.status}" (Expect: IN_USE)`);

    if (dbBooking4.status !== 'IN_USE' || dbVehicle4.status !== 'IN_USE') {
      throw new Error(`Test 4 Failed! Vehicle or Booking state not IN_USE. (Booking: ${dbBooking4.status}, Vehicle: ${dbVehicle4.status})`);
    }
    console.log('✅ [TEST 4 PASSED]\n');

    // --------------------------------------------------------
    // TEST 5: RETURN VEHICLE -> COMPLETED & Vehicle AVAILABLE
    // --------------------------------------------------------
    console.log('🧪 [TEST 5] Testing RETURN VEHICLE (Expect: HTTP 200, Booking: COMPLETED, Vehicle: AVAILABLE)');

    const res5 = await apiRequest(`${BASE_URL}/${createdBookingId}/return`, 'PUT', userToken);
    console.log(`   -> HTTP Status: ${res5.status}`);
    if (res5.status !== 200) throw new Error(`Test 5 Failed! HTTP Status is ${res5.status}: ${JSON.stringify(res5.body)}`);

    const dbBooking5 = await prisma.vehicleBooking.findUnique({ where: { id: createdBookingId } });
    const dbVehicle5 = await prisma.vehicle.findUnique({ where: { id: testVehicle.id } });

    console.log(`   -> DB Booking Status: "${dbBooking5.status}" (Expect: COMPLETED)`);
    console.log(`   -> DB Vehicle Status: "${dbVehicle5.status}" (Expect: AVAILABLE)`);

    if (dbBooking5.status !== 'COMPLETED' || dbVehicle5.status !== 'AVAILABLE') {
      throw new Error('Test 5 Failed! DB State mismatch after vehicle return.');
    }
    console.log('✅ [TEST 5 PASSED]\n');

    console.log('======================================================');
    console.log('🎉 ALL INTEGRATION TESTS PASSED SUCCESSFULLY! (ข้อ 3 = PASS)');
    console.log('======================================================\n');

  } catch (err) {
    console.error(`\n❌ [TEST FAILED]: ${err.message}\n`);
  } finally {
    // --------------------------------------------------------
    // CLEANUP: ลบข้อมูลทดสอบออกจาก DB อย่างปลอดภัย
    // --------------------------------------------------------
    console.log('🧹 [CLEANUP] Cleaning up test data from Database...');
    try {
      if (createdBookingId) {
        await prisma.vehicleLog.deleteMany({ where: { vehicleBookingId: createdBookingId } });
        await prisma.attachment.deleteMany({ where: { vehicleBookingId: createdBookingId } });
        await prisma.vehicleBooking.deleteMany({ where: { id: createdBookingId } });
      }
      if (testVehicle) {
        await prisma.vehicleDocument.deleteMany({ where: { vehicleId: testVehicle.id } });
        await prisma.vehicle.delete({ where: { id: testVehicle.id } });
      }
      if (testUser) {
        await prisma.user.delete({ where: { id: testUser.id } });
        await prisma.employee.delete({ where: { id: testUser.employeeId } });
      }
      if (testAdmin) {
        await prisma.user.delete({ where: { id: testAdmin.id } });
        await prisma.employee.delete({ where: { id: testAdmin.employeeId } });
      }
      console.log('✅ [CLEANUP COMPLETE] Database restored to original state.');
    } catch (cleanupError) {
      console.error('⚠️ [CLEANUP WARNING]:', cleanupError.message);
    } finally {
      await prisma.$disconnect();
    }
  }
}

runTestFlow();