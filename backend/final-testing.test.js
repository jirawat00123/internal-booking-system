process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
const axios = require('axios');

const BASE_URL = process.env.BASE_URL || 'https://192.168.88.25:3002/api';
const TOKENS = {
    USER: process.env.USER_TOKEN || 'MOCK_USER_TOKEN',
    GUARD: process.env.GUARD_TOKEN || 'MOCK_GUARD_TOKEN',
    ADMIN: process.env.ADMIN_TOKEN || 'MOCK_ADMIN_TOKEN',
};

const getAuthHeaders = (token) => ({
    headers: { Authorization: `Bearer ${token}` },
    validateStatus: () => true // ป้องกันไม่ให้ axios throw error เพื่อให้เช็ค status code ได้ตรงๆ
});

axios.interceptors.response.use((response) => {
    if (response.status >= 400) {
        console.log(`\n[API Error ${response.status}] ${response.config.method.toUpperCase()} ${response.config.url}:`, response.data);
    }
    return response;
});


describe('4. Final Testing Suite', () => {
    let companyBookingId = null;
    let selfDriveBookingId = null;
    const testVehicleId = 1; // เปลี่ยนให้ตรงกับ ID รถที่มีใน DB
    const testDriverId = 1;  // เปลี่ยนให้ตรงกับ ID พนักงานขับรถที่มีใน DB

    beforeAll(async () => {
        if (TOKENS.USER === 'MOCK_USER_TOKEN') {
            const res = await axios.post(`${BASE_URL}/auth/login`, { employeeId: 'user', username: 'user', password: 'password' }, { validateStatus: () => true });
            if (res.data?.token || res.data?.accessToken) TOKENS.USER = res.data.token || res.data.accessToken;
        }
        if (TOKENS.GUARD === 'MOCK_GUARD_TOKEN') {
            const res = await axios.post(`${BASE_URL}/auth/login`, { employeeId: 'guard', username: 'guard', password: 'password' }, { validateStatus: () => true });
            if (res.data?.token || res.data?.accessToken) TOKENS.GUARD = res.data.token || res.data.accessToken;
        }
        if (TOKENS.ADMIN === 'MOCK_ADMIN_TOKEN') {
            const res = await axios.post(`${BASE_URL}/auth/login`, { employeeId: 'admin', username: 'admin', password: 'password' }, { validateStatus: () => true });
            if (res.data?.token || res.data?.accessToken) TOKENS.ADMIN = res.data.token || res.data.accessToken;
        }
    });

    // ==========================================
    // 1. Company Driver — Pending & Assigned
    // ==========================================
    describe('Company Driver Flow', () => {
        it('☐ User สร้าง Booking แบบ COMPANY_DRIVER โดยไม่ระบุ companyDriverId -> สร้างสำเร็จ', async () => {
            const payload = {
                vehicleId: testVehicleId,
                bookingType: 'COMPANY_DRIVER',
                startTime: '2026-10-01T08:00:00Z',
                endTime: '2026-10-01T17:00:00Z',
                destination: 'ทดสอบสถานที่',
                purpose: 'ทดสอบการจองรถ'
            };

            const res = await axios.post(`${BASE_URL}/bookings`, payload, getAuthHeaders(TOKENS.USER));
            
            expect([200, 201]).toContain(res.status);
            expect(res.data).toHaveProperty('id');
            expect(res.data.companyDriverId).toBeFalsy();
            
            companyBookingId = res.data.id; // เก็บ ID ไว้ใช้ในข้อถัดไป
        });

        it('☐ Admin/Guard กด IN_USE เมื่อยังไม่จัดสรร Driver -> ระบบ Block และแจ้งเตือน', async () => {
            const payload = { status: 'IN_USE' };
            
            const resGuard = await axios.put(`${BASE_URL}/bookings/${companyBookingId}/status`, payload, getAuthHeaders(TOKENS.GUARD));
            expect(resGuard.status).toBe(400);
            expect(resGuard.data?.message || resGuard.data?.error || '').toMatch(/กรุณาจัดสรรพนักงานขับรถก่อน/);

            const resAdmin = await axios.put(`${BASE_URL}/bookings/${companyBookingId}/status`, payload, getAuthHeaders(TOKENS.ADMIN));
            expect(resAdmin.status).toBe(400);
            expect(resAdmin.data?.message || resAdmin.data?.error || '').toMatch(/กรุณาจัดสรรพนักงานขับรถก่อน/);
        });

        it('☐ Admin จัดสรร Company Driver -> companyDriverId ถูกบันทึก และแสดงชื่อถูกต้อง', async () => {
            const payload = { companyDriverId: testDriverId };
            
            const res = await axios.put(`${BASE_URL}/bookings/${companyBookingId}/assign-driver`, payload, getAuthHeaders(TOKENS.ADMIN));
            
            expect(res.status).toBe(200);
            expect(res.data.companyDriverId).toBe(testDriverId);
            
            // ตรวจสอบการ GET รายละเอียดว่าแสดงชื่อ Driver
            const getRes = await axios.get(`${BASE_URL}/bookings/${companyBookingId}`, getAuthHeaders(TOKENS.USER));
            expect(getRes.status).toBe(200);
            expect(getRes.data.driver || getRes.data.companyDriver).toBeDefined();
        });

        it('☐ Admin/Guard กด IN_USE หลังจัดสรร Driver แล้ว -> ระบบเปลี่ยนสถานะสำเร็จ', async () => {
            const payload = { status: 'IN_USE' };
            
            const res = await axios.put(`${BASE_URL}/bookings/${companyBookingId}/status`, payload, getAuthHeaders(TOKENS.GUARD));
            
            expect(res.status).toBe(200);
            expect(res.data.status).toBe('IN_USE');
        });
    });

    // ==========================================
    // 2. Self-Drive Flow
    // ==========================================
    describe('Self-Drive Flow', () => {
        it('☐ User เลือก SELF_DRIVE -> ผูก User เป็น Driver ไม่ต้องเลือก Company Driver', async () => {
            const payload = {
                vehicleId: testVehicleId,
                bookingType: 'SELF_DRIVE',
                startTime: '2026-10-02T08:00:00Z',
                endTime: '2026-10-02T17:00:00Z',
                destination: 'ทดสอบขับเอง',
                purpose: 'ทดสอบการจองรถ'
            };

            const res = await axios.post(`${BASE_URL}/bookings`, payload, getAuthHeaders(TOKENS.USER));
            
            expect([200, 201]).toContain(res.status);
            expect(res.data.bookingType).toBe('SELF_DRIVE');
            expect(res.data.companyDriverId).toBeFalsy();
            
            selfDriveBookingId = res.data.id;
        });

        it('☐ Self-Drive: Release / IN_USE ทำงานได้ทันทีโดยไม่ต้องจัดสรร Driver เพิ่ม', async () => {
            const payload = { status: 'IN_USE' };
            
            const res = await axios.put(`${BASE_URL}/bookings/${selfDriveBookingId}/status`, payload, getAuthHeaders(TOKENS.GUARD));
            
            expect(res.status).toBe(200);
            expect(res.data.status).toBe('IN_USE');
        });
    });

    // ==========================================
    // 3. Permission Checks (RBAC)
    // ==========================================
    describe('Permission Matrix (RBAC)', () => {
    const getAdminOnlyEndpoint = () => `${BASE_URL}/bookings/${companyBookingId}/assign-driver`;

    it('USER Role Permission Check', async () => {
        const getRes = await axios.get(`${BASE_URL}/bookings`, getAuthHeaders(TOKENS.USER));
        expect(getRes.status).toBe(200);

        const postRes = await axios.post(`${BASE_URL}/admin/manage-vehicles`, {}, getAuthHeaders(TOKENS.USER));
        expect(postRes.status).toBe(403);

        const putRes = await axios.put(getAdminOnlyEndpoint(), { companyDriverId: testDriverId }, getAuthHeaders(TOKENS.USER));
        expect(putRes.status).toBe(403);
    });

    it('GUARD Role Permission Check', async () => {
        const getRes = await axios.get(`${BASE_URL}/bookings`, getAuthHeaders(TOKENS.GUARD));
        expect(getRes.status).toBe(200);

        const postRes = await axios.post(`${BASE_URL}/admin/manage-vehicles`, {}, getAuthHeaders(TOKENS.GUARD));
        expect(postRes.status).toBe(403);

        const putRes = await axios.put(getAdminOnlyEndpoint(), { companyDriverId: testDriverId }, getAuthHeaders(TOKENS.GUARD));
        expect(putRes.status).toBe(403);
    });

    it('ADMIN Role Permission Check', async () => {
        const getRes = await axios.get(`${BASE_URL}/bookings`, getAuthHeaders(TOKENS.ADMIN));
        expect(getRes.status).toBe(200);

        const putRes = await axios.put(getAdminOnlyEndpoint(), { companyDriverId: testDriverId }, getAuthHeaders(TOKENS.ADMIN));
        expect(putRes.status).toBe(200);
    });
});
});