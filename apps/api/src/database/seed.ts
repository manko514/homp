import { PrismaClient, Role, EmploymentType } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding database...');

  // Create demo tenant
  const tenant = await prisma.tenant.upsert({
    where: { subdomain: 'demo' },
    update: {},
    create: {
      name: 'Grand HOMP Hotel',
      subdomain: 'demo',
      primaryColor: '#1E3A5F',
    },
  });

  console.log(`Tenant: ${tenant.name} (${tenant.id})`);

  // Create admin user
  const adminHash = await bcrypt.hash('admin123', 12);
  const admin = await prisma.user.upsert({
    where: { tenantId_email: { tenantId: tenant.id, email: 'admin@homp.demo' } },
    update: {},
    create: {
      tenantId: tenant.id,
      name: 'Admin User',
      email: 'admin@homp.demo',
      passwordHash: adminHash,
      role: Role.ADMIN,
    },
  });

  // Create receptionist
  const recHash = await bcrypt.hash('staff123', 12);
  await prisma.user.upsert({
    where: { tenantId_email: { tenantId: tenant.id, email: 'receptionist@homp.demo' } },
    update: {},
    create: {
      tenantId: tenant.id,
      name: 'Jane Receptionist',
      email: 'receptionist@homp.demo',
      passwordHash: recHash,
      role: Role.RECEPTIONIST,
    },
  });

  // Create waiter
  const waiter = await prisma.user.upsert({
    where: { tenantId_email: { tenantId: tenant.id, email: 'waiter@homp.demo' } },
    update: {},
    create: {
      tenantId: tenant.id,
      name: 'John Waiter',
      email: 'waiter@homp.demo',
      passwordHash: recHash,
      role: Role.WAITER,
    },
  });

  // Create bartender
  const bartender = await prisma.user.upsert({
    where: { tenantId_email: { tenantId: tenant.id, email: 'bartender@homp.demo' } },
    update: {},
    create: {
      tenantId: tenant.id,
      name: 'Sam Bartender',
      email: 'bartender@homp.demo',
      passwordHash: recHash,
      role: Role.BARTENDER,
    },
  });

  // Create housekeeper
  const housekeeper = await prisma.user.upsert({
    where: { tenantId_email: { tenantId: tenant.id, email: 'housekeeper@homp.demo' } },
    update: {},
    create: {
      tenantId: tenant.id,
      name: 'Mary Housekeeper',
      email: 'housekeeper@homp.demo',
      passwordHash: recHash,
      role: Role.HOUSEKEEPER,
    },
  });

  // Create manager
  const manager = await prisma.user.upsert({
    where: { tenantId_email: { tenantId: tenant.id, email: 'manager@homp.demo' } },
    update: {},
    create: {
      tenantId: tenant.id,
      name: 'Grace Manager',
      email: 'manager@homp.demo',
      passwordHash: recHash,
      role: Role.MANAGER,
    },
  });

  // ── Seed Employees ────────────────────────────────────────────────────────
  const employeeData = [
    { user: admin,       salary: 3500, type: EmploymentType.FULL_TIME,  momo: '0244000001' },
    { user: waiter,      salary: 1200, type: EmploymentType.FULL_TIME,  momo: '0244000002' },
    { user: bartender,   salary: 1400, type: EmploymentType.FULL_TIME,  momo: '0244000003' },
    { user: housekeeper, salary: 1100, type: EmploymentType.PART_TIME,  momo: '0244000004' },
    { user: manager,     salary: 2800, type: EmploymentType.FULL_TIME,  momo: '0244000005' },
  ];

  for (const e of employeeData) {
    const existing = await prisma.employee.findUnique({ where: { userId: e.user.id } });
    if (!existing) {
      await prisma.employee.create({
        data: {
          tenantId: tenant.id,
          userId: e.user.id,
          employmentType: e.type,
          basicSalary: e.salary,
          overtimeRate: e.salary / 160,
          hireDate: new Date('2024-01-01'),
          momoNumber: e.momo,
        },
      });
    }
  }

  // Seed rooms
  const roomTypes = [
    { type: 'Standard', floor: 1, baseRate: 120 },
    { type: 'Standard', floor: 1, baseRate: 120 },
    { type: 'Deluxe', floor: 2, baseRate: 200 },
    { type: 'Deluxe', floor: 2, baseRate: 200 },
    { type: 'Suite', floor: 3, baseRate: 350 },
  ];

  for (let i = 0; i < roomTypes.length; i++) {
    const rt = roomTypes[i];
    await prisma.room.upsert({
      where: { tenantId_roomNumber: { tenantId: tenant.id, roomNumber: `10${i + 1}` } },
      update: {},
      create: {
        tenantId: tenant.id,
        roomNumber: `10${i + 1}`,
        type: rt.type,
        floor: rt.floor,
        baseRate: rt.baseRate,
        amenities: ['WiFi', 'AC', 'TV'],
      },
    });
  }

  // Seed restaurant tables
  for (let i = 1; i <= 8; i++) {
    await prisma.restaurantTable.upsert({
      where: { tenantId_tableNumber: { tenantId: tenant.id, tableNumber: i } },
      update: {},
      create: {
        tenantId: tenant.id,
        tableNumber: i,
        capacity: i <= 4 ? 2 : 4,
      },
    });
  }

  // Seed menu items
  const menuItems = [
    { name: 'Club Sandwich', category: 'Mains', price: 12.50 },
    { name: 'Caesar Salad', category: 'Starters', price: 9.00 },
    { name: 'Grilled Salmon', category: 'Mains', price: 22.00 },
    { name: 'Chocolate Lava Cake', category: 'Desserts', price: 8.00 },
    { name: 'Fresh Orange Juice', category: 'Beverages', price: 5.00 },
  ];

  for (const item of menuItems) {
    await prisma.menuItem.upsert({
      where: { id: `seed-${item.name.replace(/\s/g, '-').toLowerCase()}` },
      update: {},
      create: {
        id: `seed-${item.name.replace(/\s/g, '-').toLowerCase()}`,
        tenantId: tenant.id,
        ...item,
      },
    });
  }

  // Seed stock items
  const stockItems = [
    { name: 'Chicken Breast', category: 'Meat', unit: 'kg', currentQty: 20, reorderLevel: 5 },
    { name: 'Romaine Lettuce', category: 'Vegetables', unit: 'kg', currentQty: 10, reorderLevel: 2 },
    { name: 'Whiskey (750ml)', category: 'Spirits', unit: 'bottle', currentQty: 24, reorderLevel: 6 },
    { name: 'Red Wine (750ml)', category: 'Wine', unit: 'bottle', currentQty: 36, reorderLevel: 12 },
    { name: 'Toilet Paper', category: 'Housekeeping', unit: 'roll', currentQty: 200, reorderLevel: 50 },
  ];

  for (const item of stockItems) {
    await prisma.stockItem.upsert({
      where: { id: `seed-stock-${item.name.replace(/\s/g, '-').toLowerCase()}` },
      update: {},
      create: {
        id: `seed-stock-${item.name.replace(/\s/g, '-').toLowerCase()}`,
        tenantId: tenant.id,
        ...item,
      },
    });
  }

  // ── Seed Tickets ─────────────────────────────────────────────────────────
  const now = new Date();
  const ticketData = [
    { guestName: 'Kwame Mensah',  ticketType: 'DAY_PASS',  price: 50,  status: 'ACTIVE',    hoursAgo: 1 },
    { guestName: 'Abena Osei',    ticketType: 'POOL_ONLY', price: 30,  status: 'USED',     hoursAgo: 2 },
    { guestName: 'John Doe',      ticketType: 'VIP',       price: 150, status: 'ACTIVE',    hoursAgo: 0 },
    { guestName: 'Mary Asante',   ticketType: 'GYM',       price: 25,  status: 'ACTIVE',    hoursAgo: 3 },
    { guestName: 'Walk-in Guest', ticketType: 'DAY_PASS',  price: 50,  status: 'EXPIRED',   hoursAgo: 26 },
  ];

  for (let i = 0; i < ticketData.length; i++) {
    const td = ticketData[i];
    const createdAt = new Date(now.getTime() - td.hoursAgo * 3_600_000);
    const validFrom = new Date(createdAt);
    const validUntil = new Date(createdAt.getTime() + (td.status === 'EXPIRED' ? 1 : 24) * 3_600_000);
    const existing = await prisma.ticket.findFirst({
      where: { tenantId: tenant.id, guestName: td.guestName, ticketType: td.ticketType },
    });
    if (!existing) {
      await prisma.ticket.create({
        data: {
          tenantId: tenant.id,
          guestName: td.guestName,
          ticketType: td.ticketType,
          qrToken: `HOMP-SEED${String(i + 1).padStart(4, '0')}DEMO${String(i).padStart(4, '0')}`,
          validFrom,
          validUntil,
          purchasePrice: td.price,
          status: td.status as 'ACTIVE' | 'USED' | 'EXPIRED' | 'CANCELLED',
          usedAt: td.status === 'USED' ? new Date(createdAt.getTime() + 3_600_000) : null,
        },
      });
    }
  }

  console.log('Seed complete!');
  console.log(`\nDemo credentials (tenantId: ${tenant.id}):`);
  console.log('  admin@homp.demo / admin123 (ADMIN)');
  console.log('  receptionist@homp.demo / staff123 (RECEPTIONIST)');
  console.log('  waiter@homp.demo / staff123 (WAITER)');
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
