FROM node:18-alpine

WORKDIR /app

# ติดตั้ง Python และ Build Tools สำหรับคอมไพล์ argon2
RUN apk add --no-cache python3 make g++

# คัดลอก package.json และ prisma schema เพื่อลง Dependencies
COPY package*.json ./
COPY prisma ./prisma/

RUN npm install
RUN npx prisma generate

# คัดลอก ซอร์สโค้ดทั้งหมด
COPY . .

# สร้างโฟลเดอร์ uploads รอไว้กรณีไม่มี
RUN mkdir -p uploads

EXPOSE 3001

CMD ["node", "src/index.js"]