import { PrismaClient, Role, EmploymentType, ReservationStatus, PaymentStatus, OrderStatus } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

function daysAgo(n: number, hour = 12): Date {
  const d = new Date();
  d.setDate(d.getDate() - n);
  d.setHours(hour, 0, 0, 0);
  return d;
}

function rand(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

async function main() {
  console.log('Seeding database...');

  // ── Tenant ─────────────────────────────────────────────────────────────────
  const tenant = await prisma.tenant.upsert({
    where: { subdomain: 'demo' },
    update: {},
    create: {
      name: 'Grand HOMP Hotel',
      subdomain: 'demo',
      primaryColor: '#1E3A5F',
    },
  });
  console.log(`Tenant: ${tenant.name}`);

  // ── Users ──────────────────────────────────────────────────────────────────
  const adminHash = await bcrypt.hash('admin123', 12);
  const staffHash = await bcrypt.hash('staff123', 12);

  const upsertUser = (email: string, name: string, role: Role, hash: string) =>
    prisma.user.upsert({
      where: { tenantId_email: { tenantId: tenant.id, email } },
      update: {},
      create: { tenantId: tenant.id, name, email, passwordHash: hash, role },
    });

  const admin       = await upsertUser('admin@homp.demo',        'Admin User',        Role.ADMIN,        adminHash);
  const receptionist= await upsertUser('receptionist@homp.demo', 'Jane Receptionist', Role.RECEPTIONIST, staffHash);
  const waiter      = await upsertUser('waiter@homp.demo',       'John Waiter',       Role.WAITER,       staffHash);
  const bartender   = await upsertUser('bartender@homp.demo',    'Sam Bartender',     Role.BARTENDER,    staffHash);
  const housekeeper = await upsertUser('housekeeper@homp.demo',  'Mary Housekeeper',  Role.HOUSEKEEPER,  staffHash);
  const manager     = await upsertUser('manager@homp.demo',      'Grace Manager',     Role.MANAGER,      staffHash);

  // Guest users for reservations
  const guestNames = [
    ['Kwame Mensah', 'kwame@email.com'],
    ['Abena Osei', 'abena@email.com'],
    ['James Asante', 'james@email.com'],
    ['Linda Boateng', 'linda@email.com'],
    ['Eric Adjei', 'eric@email.com'],
    ['Sandra Owusu', 'sandra@email.com'],
    ['Daniel Antwi', 'daniel@email.com'],
    ['Patricia Darko', 'patricia@email.com'],
  ];
  const guests: Awaited<ReturnType<typeof upsertUser>>[] = [];
  for (const [name, email] of guestNames) {
    guests.push(await upsertUser(email, name, Role.GUEST, staffHash));
  }

  // ── Employees ──────────────────────────────────────────────────────────────
  const empData = [
    { user: admin,        salary: 3500, type: EmploymentType.FULL_TIME,  momo: '0244000001' },
    { user: receptionist, salary: 1300, type: EmploymentType.FULL_TIME,  momo: '0244000002' },
    { user: waiter,       salary: 1200, type: EmploymentType.FULL_TIME,  momo: '0244000003' },
    { user: bartender,    salary: 1400, type: EmploymentType.FULL_TIME,  momo: '0244000004' },
    { user: housekeeper,  salary: 1100, type: EmploymentType.PART_TIME,  momo: '0244000005' },
    { user: manager,      salary: 2800, type: EmploymentType.FULL_TIME,  momo: '0244000006' },
  ];
  for (const e of empData) {
    const existing = await prisma.employee.findUnique({ where: { userId: e.user.id } });
    if (!existing) {
      await prisma.employee.create({
        data: {
          tenantId: tenant.id,
          userId: e.user.id,
          employmentType: e.type,
          basicSalary: e.salary,
          overtimeRate: +(e.salary / 160).toFixed(2),
          hireDate: new Date('2024-01-01'),
          momoNumber: e.momo,
        },
      });
    }
  }

  // ── Rooms (20 rooms across 4 floors) ───────────────────────────────────────
  const roomDefs = [
    ...Array.from({ length: 8 }, (_, i) => ({ number: `10${i + 1}`, type: 'Standard',  floor: 1, rate: 120 })),
    ...Array.from({ length: 6 }, (_, i) => ({ number: `20${i + 1}`, type: 'Deluxe',    floor: 2, rate: 200 })),
    ...Array.from({ length: 4 }, (_, i) => ({ number: `30${i + 1}`, type: 'Junior Suite', floor: 3, rate: 300 })),
    ...Array.from({ length: 2 }, (_, i) => ({ number: `40${i + 1}`, type: 'Presidential Suite', floor: 4, rate: 500 })),
  ];
  const rooms: Awaited<ReturnType<typeof prisma.room.upsert>>[] = [];
  for (const r of roomDefs) {
    rooms.push(await prisma.room.upsert({
      where: { tenantId_roomNumber: { tenantId: tenant.id, roomNumber: r.number } },
      update: {},
      create: {
        tenantId: tenant.id,
        roomNumber: r.number,
        type: r.type,
        floor: r.floor,
        baseRate: r.rate,
        amenities: ['WiFi', 'AC', 'TV', 'Mini Bar'],
        photos: [],
      },
    }));
  }

  // ── Restaurant Tables ──────────────────────────────────────────────────────
  const tables: Awaited<ReturnType<typeof prisma.restaurantTable.upsert>>[] = [];
  for (let i = 1; i <= 10; i++) {
    tables.push(await prisma.restaurantTable.upsert({
      where: { tenantId_tableNumber: { tenantId: tenant.id, tableNumber: i } },
      update: {},
      create: { tenantId: tenant.id, tableNumber: i, capacity: i <= 5 ? 2 : 4 },
    }));
  }

  // ── Menu Items ─────────────────────────────────────────────────────────────
  const menuDefs = [
    { name: 'Club Sandwich',        category: 'Mains',      price: 12.50 },
    { name: 'Caesar Salad',         category: 'Starters',   price: 9.00  },
    { name: 'Grilled Salmon',       category: 'Mains',      price: 22.00 },
    { name: 'Chicken Tikka Masala', category: 'Mains',      price: 18.00 },
    { name: 'Beef Burger',          category: 'Mains',      price: 15.00 },
    { name: 'Margherita Pizza',     category: 'Mains',      price: 16.00 },
    { name: 'Tom Yum Soup',         category: 'Starters',   price: 8.50  },
    { name: 'Chocolate Lava Cake',  category: 'Desserts',   price: 8.00  },
    { name: 'Cheesecake',           category: 'Desserts',   price: 7.00  },
    { name: 'Fresh Orange Juice',   category: 'Beverages',  price: 5.00  },
  ];
  const menuItems: Awaited<ReturnType<typeof prisma.menuItem.upsert>>[] = [];
  for (const m of menuDefs) {
    const id = `seed-menu-${m.name.replace(/\s/g, '-').toLowerCase()}`;
    menuItems.push(await prisma.menuItem.upsert({
      where: { id },
      update: {},
      create: { id, tenantId: tenant.id, ...m },
    }));
  }

  // ── Drinks ─────────────────────────────────────────────────────────────────
  const drinkDefs = [
    { name: 'Johnnie Walker Black',  category: 'Whiskey',    price: 12.00 },
    { name: 'Heineken',              category: 'Beer',       price: 5.00  },
    { name: 'Club Beer',             category: 'Beer',       price: 4.00  },
    { name: 'Merlot Red Wine',       category: 'Wine',       price: 9.00  },
    { name: 'Chardonnay',            category: 'Wine',       price: 9.00  },
    { name: 'Mojito',                category: 'Cocktails',  price: 10.00 },
    { name: 'Pina Colada',           category: 'Cocktails',  price: 11.00 },
    { name: 'Campari & Soda',        category: 'Cocktails',  price: 9.00  },
    { name: 'Still Water (500ml)',   category: 'Soft',       price: 2.50  },
    { name: 'Coca Cola',             category: 'Soft',       price: 3.00  },
  ];
  const drinks: Awaited<ReturnType<typeof prisma.drink.upsert>>[] = [];
  for (const d of drinkDefs) {
    const id = `seed-drink-${d.name.replace(/\s/g, '-').toLowerCase()}`;
    drinks.push(await prisma.drink.upsert({
      where: { id },
      update: {},
      create: { id, tenantId: tenant.id, ...d },
    }));
  }

  // ── Stock Items ────────────────────────────────────────────────────────────
  const stockDefs = [
    { name: 'Chicken Breast',    category: 'Meat',         unit: 'kg',     currentQty: 20,  reorderLevel: 5  },
    { name: 'Romaine Lettuce',   category: 'Vegetables',   unit: 'kg',     currentQty: 10,  reorderLevel: 2  },
    { name: 'Whiskey (750ml)',   category: 'Spirits',      unit: 'bottle', currentQty: 24,  reorderLevel: 6  },
    { name: 'Red Wine (750ml)',  category: 'Wine',         unit: 'bottle', currentQty: 36,  reorderLevel: 12 },
    { name: 'Heineken (24pk)',   category: 'Beer',         unit: 'case',   currentQty: 8,   reorderLevel: 3  },
    { name: 'Toilet Paper',      category: 'Housekeeping', unit: 'roll',   currentQty: 200, reorderLevel: 50 },
    { name: 'Cooking Oil',       category: 'Pantry',       unit: 'litre',  currentQty: 15,  reorderLevel: 4  },
    { name: 'Rice',              category: 'Pantry',       unit: 'kg',     currentQty: 50,  reorderLevel: 10 },
  ];
  const stockItems: Awaited<ReturnType<typeof prisma.stockItem.upsert>>[] = [];
  for (const s of stockDefs) {
    const id = `seed-stock-${s.name.replace(/\s/g, '-').toLowerCase()}`;
    stockItems.push(await prisma.stockItem.upsert({
      where: { id },
      update: {},
      create: { id, tenantId: tenant.id, ...s },
    }));
  }

  // ── Historical Reservations (30 days) ─────────────────────────────────────
  // Skip if already seeded
  const existingRes = await prisma.reservation.count({ where: { tenantId: tenant.id } });
  if (existingRes === 0) {
    console.log('Creating 30 days of reservations...');
    for (let day = 30; day >= 0; day--) {
      const numRes = rand(2, 5);
      for (let r = 0; r < numRes; r++) {
        const guest = guests[rand(0, guests.length - 1)];
        const room  = rooms[rand(0, rooms.length - 1)];
        const nights = rand(1, 3);
        const checkIn  = daysAgo(day, 14);
        const checkOut = new Date(checkIn);
        checkOut.setDate(checkOut.getDate() + nights);
        const rate = Number(room.baseRate);
        const total = rate * nights;
        const isPast = day > 0;
        await prisma.reservation.create({
          data: {
            tenantId: tenant.id,
            guestId: guest.id,
            roomId: room.id,
            checkIn,
            checkOut,
            status: isPast ? ReservationStatus.CHECKED_OUT : ReservationStatus.CHECKED_IN,
            totalAmount: total,
            paymentStatus: PaymentStatus.PAID,
            bookingSource: ['direct', 'booking.com', 'expedia', 'walk-in'][rand(0, 3)],
          },
        });
      }
    }
  }

  // ── Historical Restaurant Orders (30 days) ────────────────────────────────
  const existingOrders = await prisma.order.count({ where: { tenantId: tenant.id } });
  if (existingOrders === 0) {
    console.log('Creating 30 days of restaurant orders...');
    for (let day = 30; day >= 0; day--) {
      const numOrders = rand(4, 10);
      for (let o = 0; o < numOrders; o++) {
        const table = tables[rand(0, tables.length - 1)];
        const item1 = menuItems[rand(0, menuItems.length - 1)];
        const item2 = menuItems[rand(0, menuItems.length - 1)];
        const qty1 = rand(1, 3);
        const qty2 = rand(1, 2);
        const total = Number(item1.price) * qty1 + Number(item2.price) * qty2;
        const createdAt = daysAgo(day, rand(7, 22));
        const order = await prisma.order.create({
          data: {
            tenantId: tenant.id,
            tableId: table.id,
            waiterId: waiter.id,
            status: OrderStatus.SERVED,
            total,
            isRoomService: false,
            createdAt,
            updatedAt: createdAt,
          },
        });
        await prisma.orderItem.createMany({
          data: [
            { orderId: order.id, menuItemId: item1.id, qty: qty1, unitPrice: item1.price },
            { orderId: order.id, menuItemId: item2.id, qty: qty2, unitPrice: item2.price },
          ],
        });
      }
    }
  }

  // ── Historical Bar Sales (30 days) ────────────────────────────────────────
  const existingBarSales = await prisma.barSale.count({ where: { tenantId: tenant.id } });
  if (existingBarSales === 0) {
    console.log('Creating 30 days of bar sales...');
    for (let day = 30; day >= 0; day--) {
      const numSales = rand(5, 15);
      for (let s = 0; s < numSales; s++) {
        const drink = drinks[rand(0, drinks.length - 1)];
        const qty = rand(1, 4);
        const createdAt = daysAgo(day, rand(17, 23));
        await prisma.barSale.create({
          data: {
            tenantId: tenant.id,
            drinkId: drink.id,
            bartenderId: bartender.id,
            qty,
            total: Number(drink.price) * qty,
            wasteQty: 0,
            createdAt,
          },
        });
      }
    }
  }

  // ── Tickets ────────────────────────────────────────────────────────────────
  const existingTickets = await prisma.ticket.count({ where: { tenantId: tenant.id } });
  if (existingTickets === 0) {
    const ticketDefs = [
      { guestName: 'Kwame Mensah',  type: 'DAY_PASS',  price: 50,  status: 'ACTIVE' as const,   hAgo: 1  },
      { guestName: 'Abena Osei',    type: 'POOL_ONLY', price: 30,  status: 'USED' as const,     hAgo: 2  },
      { guestName: 'John Doe',      type: 'VIP',       price: 150, status: 'ACTIVE' as const,   hAgo: 0  },
      { guestName: 'Mary Asante',   type: 'GYM',       price: 25,  status: 'ACTIVE' as const,   hAgo: 3  },
      { guestName: 'Walk-in Guest', type: 'DAY_PASS',  price: 50,  status: 'EXPIRED' as const,  hAgo: 26 },
    ];
    for (let i = 0; i < ticketDefs.length; i++) {
      const td = ticketDefs[i];
      const createdAt  = new Date(Date.now() - td.hAgo * 3_600_000);
      const validFrom  = createdAt;
      const validUntil = new Date(createdAt.getTime() + (td.status === 'EXPIRED' ? 1 : 24) * 3_600_000);
      await prisma.ticket.create({
        data: {
          tenantId: tenant.id,
          guestName: td.guestName,
          ticketType: td.type,
          qrToken: `HOMP-SEED${String(i + 1).padStart(4, '0')}DEMO${String(i).padStart(4, '0')}`,
          validFrom,
          validUntil,
          purchasePrice: td.price,
          status: td.status,
          usedAt: td.status === 'USED' ? new Date(createdAt.getTime() + 3_600_000) : null,
        },
      });
    }
  }

  // ── Anomaly Alerts ─────────────────────────────────────────────────────────
  const existingAlerts = await prisma.anomalyAlert.count({ where: { tenantId: tenant.id } });
  if (existingAlerts === 0) {
    await prisma.anomalyAlert.createMany({
      data: [
        {
          tenantId: tenant.id,
          shiftDate: daysAgo(1),
          severity: 'MEDIUM',
          category: 'bar',
          title: 'Bar wastage spike',
          description: 'Wastage is 3× the 7-day average for spirits.',
          dataJson: { actual: 9, baseline: 3 },
          resolved: false,
        },
        {
          tenantId: tenant.id,
          shiftDate: daysAgo(2),
          severity: 'LOW',
          category: 'restaurant',
          title: 'Slow lunch service',
          description: 'Average ticket time exceeded 40 min at lunch.',
          dataJson: { avgMinutes: 43, threshold: 30 },
          resolved: true,
          resolvedAt: daysAgo(1),
        },
      ],
    });
  }

  console.log('\nSeed complete!');
  console.log('  subdomain : demo');
  console.log('  admin     : admin@homp.demo / admin123');
  console.log('  staff     : receptionist|waiter|bartender|housekeeper|manager @homp.demo / staff123');
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
