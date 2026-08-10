const { Server } = require('socket.io');

class SocketService {
  constructor() {
    this.io = null;
  }

  // เริ่มต้นการทำงานของ Socket.io Server
  init(server) {
    this.io = new Server(server, {
      cors: {
        origin: '*', // ใน Production สามารถระบุ Domain ที่อนุญาตได้
        methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']
      }
    });

    this.io.on('connection', (socket) => {
      console.log(`⚡ [Socket.io] Client connected: ${socket.id}`);

      socket.on('disconnect', () => {
        console.log(`🔌 [Socket.io] Client disconnected: ${socket.id}`);
      });
    });

    console.log('🚀 [Socket.io] Service Initialized Successfully.');
  }

  // ดึง Instance io ออกไปใช้งาน
  getIo() {
    if (!this.io) {
      throw new Error("Socket.io is not initialized!");
    }
    return this.io;
  }

  // 1. Broadcast เมื่อสร้างการจอง
  notifyBookingCreated(booking, entityType) {
    if (this.io) {
      this.io.emit('BOOKING_CREATED', {
        entityType, // 'ROOM' หรือ 'VEHICLE'
        booking,
        timestamp: new Date()
      });
    }
  }

  // 2. Broadcast เมื่ออัปเดตการจอง
  notifyBookingUpdated(booking, entityType) {
    if (this.io) {
      this.io.emit('BOOKING_UPDATED', {
        entityType, // 'ROOM' หรือ 'VEHICLE'
        booking,
        timestamp: new Date()
      });
    }
  }

  // 3. Broadcast เมื่อยกเลิกการจอง
  notifyBookingCancelled(bookingId, entityType) {
    if (this.io) {
      this.io.emit('BOOKING_CANCELLED', {
        bookingId,
        entityType, // 'ROOM' หรือ 'VEHICLE'
        timestamp: new Date()
      });
    }
  }

  // 4. Broadcast เมื่อสถานะของห้องประชุมอัปเดต (เช่น เปลี่ยนเป็น IN_USE/AVAILABLE จาก Cron Job)
  notifyRoomUpdated(roomId, status) {
    if (this.io) {
      this.io.emit('ROOM_UPDATED', {
        roomId,
        status,
        timestamp: new Date()
      });
    }
  }

  // 5. Broadcast เมื่อสถานะของรถยนต์อัปเดต
  notifyVehicleUpdated(vehicleId, status) {
    if (this.io) {
      this.io.emit('VEHICLE_UPDATED', {
        vehicleId,
        status,
        timestamp: new Date()
      });
    }
  }
}

module.exports = new SocketService();